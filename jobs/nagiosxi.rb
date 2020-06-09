require 'rest-client'
require 'json'

########################################################################################################
# make sure you edit these variables to fit your environment
apiKey = 'your nagios api key here'
nagiosHOST = 'your nagios XI host hostname here'
########################################################################################################

hostsURL = 'https://' + nagiosHOST + '/nagiosxi/api/v1/objects/hoststatus?apikey=' + apiKey
servicesURL = 'https://' + nagiosHOST + '/nagiosxi/api/v1/objects/servicestatus?apikey=' + apiKey + '&current_state=ne:0'

#nagios hosts codes: 0=ok, 1=down, 2=unreachable
#nagios services codes: 0=ok, 1=warning, 2=critical, 3=unknown
#smashing nagios status codes: 4=critical, 3=warning, 2=unknown, 1=scheduled, 0=acknowledged
def getServiceLevel(state,scheduled,acknowledged)
    returnStatus = 4
    case state
    when 1 #warning
        returnStatus = 3
    when 2 #critical
        returnStatus = 4
    when 3 #unknown
        returnStatus = 2
    when 4 #host down
        returnStatus = 4
    else 
        returnStatus = 2
    end

    if acknowledged
        returnStatus = 0
    elsif scheduled
        returnStatus = 1
    end

    return returnStatus
end

def getLevelIcon(status)
    case status
    when 0 #acknowledged
        return 'fa-briefcase'
    when 1 #scheduled
        return 'fa-clock-o'
    when 2 #unknown
        return 'fa-question'
    when 3 #warning
        return 'fa-exclamation-triangle'
    when 4 #critical
        return 'fa-exclamation-circle'
    end
    return 'fa-question'
end

SCHEDULER.every '20', :first_in => 0 do
    hostsStatus = ""
    hostsResponse = RestClient::Request.new({
        method: :get,
        url: hostsURL,
        verify_ssl: false
    }).execute do |hostsResponse, request, result|
        case hostsResponse.code
        when 200
            hostsStatus = JSON.parse(hostsResponse.to_str)
        else
            fail "error: #{hostsResponse.to_str}"
        end
    end

    servicesStatus = ""
    servicesResponse = RestClient::Request.new({
        method: :get,
        url: servicesURL,
        verify_ssl: false
    }).execute do |servicesResponse, request, result|
        case servicesResponse.code
        when 200
            servicesStatus = JSON.parse(servicesResponse.to_str)
        else
            fail "error: #{servicesResponse.to_str}"
        end
    end 

    nagios_hosts_count = {"up" => 0, "down" => 0, "unreachable" => 0, "scheduled" => 0, "ack" => 0}
    nagios_services_count = {"ok" => 0,"warning" => 0, "critical" => 0, "unknown" => 0, "pending" => 0, "ack" => 0, "scheduled" => 0}

    nagios_message = ['','','','','']

    nagios_hosts_highest_status = 0;
    nagios_services_highest_status = 0;

    hosts = {}

    if (hostsStatus['hoststatus'].respond_to? :each and servicesStatus['servicestatus'].respond_to? :each)

        hostsStatus['hoststatus'].each do |child|
            host_current_state = child['current_state'].to_i
            host_name = child['host_name']

            case host_current_state
            when 0 #up
                nagios_hosts_count["up"] += 1
            else
                hosts[host_name] == nil ? hosts[host_name] = {} : nil
                hosts[host_name]['ack'] = child['problem_has_been_acknowledged'] == "0" ? false : true
                hosts[host_name]['scheduled'] = child['scheduled_downtime_depth'] == "0" ? false : true
                hosts[host_name]['state'] = 1
                hosts[host_name]['alias'] = child['host_alias']
                hosts[host_name]['services'] = []

                if hosts[host_name]['scheduled']
                    nagios_hosts_count["scheduled"] += 1
                elsif hosts[host_name]['ack']
                    nagios_hosts_count["ack"] +=1
                else
                    nagios_hosts_count["down"] +=1
                    nagios_hosts_highest_status = 3
                end
            end
        end

        servicesStatus['servicestatus'].each do |child|
            if servicesStatus['recordcount'] == "1"
                child = servicesStatus['servicestatus']
            end
            service = {}
            service['ack'] = child['problem_has_been_acknowledged'].to_s == "0" ? false : true
            service['scheduled'] = child['scheduled_downtime_depth'].to_s == "0" ? false : true
            service['state'] = child['current_state'].to_i
            service['name'] = child['display_name'].to_s
            service['state'] == 3 ?  service['text'] = 'Unknown' : service['text'] = child['output'].to_s
                
            host_name = child['host_name']
            host_alias = child['host_alias']

            if service['state'] == 0
                nagios_services_count["ok"] += 1
            else
                hosts[host_name] == nil ? hosts[host_name] = {} : nil
                hosts[host_name]['ack'] == nil ? hosts[host_name]['ack'] = 0 : nil
                hosts[host_name]['scheduled'] == nil ? hosts[host_name]['scheduled'] = 0 : nil
                hosts[host_name]['state'] == nil ? hosts[host_name]['state'] = 0 : nil
                hosts[host_name]['alias'] == nil ? hosts[host_name]['alias'] = host_alias : nil
                hosts[host_name]['services'] == nil ? hosts[host_name]['services'] = [] : nil
                hosts[host_name]['services'].push(service)

                if service['scheduled']
                    nagios_services_count["scheduled"] += 1
                elsif service['ack']
                    nagios_services_count["ack"] +=1
                end

                case service['state']                    
                when 1 #warning
                    nagios_services_count["warning"] += 1
                    if !service['ack'] and !service['scheduled'] and nagios_services_highest_status < 3
                        nagios_services_highest_status = 3
                    end
                when 2 #critical
                    nagios_services_count["critical"] += 1
                    if !service['ack'] and !service['scheduled'] and nagios_services_highest_status < 4
                        nagios_services_highest_status = 4
                    end
                when 3 #unknown
                    nagios_services_count["unknown"] += 1
                    if !service['ack'] and !service['scheduled'] and nagios_services_highest_status < 2
                        nagios_services_highest_status = 2
                    end
                else #pending
                    nagios_services_count["pending"] += 1
                    if !service['ack'] and !service['scheduled'] and nagios_services_highest_status < 1
                        nagios_services_highest_status = 1
                    end
                end
            end
            break if servicesStatus['recordcount'] == "1"
        end

        hosts.each do |key, host|
            msg_tmp = ''
            msg_level = 0
            if host['state'] != 0
                msg_level = getServiceLevel(4,host['scheduled'],host['ack'])
                msg_tmp = "<p class='single-message-header'><i class='fa " + getLevelIcon(msg_level) + "'></i><span class='servername'>" + host['alias'].to_s + "</span><span class='detail'>HOST DOWN</span></p>"
            else
                services_shown = 0
                host['services'].each do |service|
                    service_level = getServiceLevel(service['state'],service['scheduled'],service['ack'])
                    msg_level < service_level ? msg_level = service_level : nil
                    if services_shown < 3
                        msg_tmp += "<p class='single-message-body'><i class='fa " + getLevelIcon(service_level) + "'></i><span>" + service['name'] + " - " + service['text'] + "</span></p>"
                    elsif services_shown == 3
                        msg_tmp += "<p class='single-message-body'><i class='fa " + getLevelIcon(4) + "'></i><span>... other services ...</span></p>"
                    end
                    services_shown+=1
                end
                msg_tmp = "<p class='single-message-header'><i class='fa " + getLevelIcon(msg_level) + "'></i><span class='servername'>" + host['alias'].to_s + "</span></p>" + msg_tmp
            end
            nagios_message[msg_level] += msg_tmp
        end

        send_event('messages', { nagios_message: nagios_message[4] + nagios_message[3] + nagios_message[2] + nagios_message[1] + nagios_message[0]}) 

        hoststatus = nagios_hosts_highest_status == 3 ? "red" : (nagios_hosts_highest_status == 2 ? "yellow" : (nagios_hosts_highest_status > 0 ? "grey" : "green"))
        servicestatus = nagios_services_highest_status == 4 ? "red" : (nagios_services_highest_status == 3 ? "yellow" : (nagios_services_highest_status > 0 ? "grey" : "green"))
        
        nagiosstatus = servicestatus
        if nagios_hosts_highest_status >= nagios_services_highest_status
            nagiosstatus = hoststatus
        end

        send_event('nagiosxi', { nagiosstatus: nagiosstatus})

    else #no data from nagios server
        send_event('nagiosxi', { nagiosstatus: nagiosstatus})
        send_event('messages', { nagios_message: nagios_message}) 

    end

end
