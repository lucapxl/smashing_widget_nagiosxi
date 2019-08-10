require 'open-uri'
require 'json'

#nagios api key
apiKey = 'your nagios api key here'
nagiosIP = 'your nagios XI server IP'

hostsURL = 'http://' + nagiosIP + '/nagiosxi/api/v1/objects/hoststatus?apikey=' + apiKey
servicesURL = 'http://' + nagiosIP + '/nagiosxi/api/v1/objects/servicestatus?apikey=' + apiKey


SCHEDULER.every '60', :first_in => 0 do
  resp = Net::HTTP.get_response(URI.parse(hostsURL))
  jsonData = resp.body
  hostsStatus = JSON.parse(jsonData)

  resp2 = Net::HTTP.get_response(URI.parse(servicesURL))
  jsonData2 = resp2.body
  servicesStatus = JSON.parse(jsonData2)

  nagios_hosts_count = [0,0,0,0]
  nagios_services_count = [0,0,0,0,0]

  #status for hosts will be: 0=ok, 1=pending, 2=unreachable, 3=down
  nagios_hosts_highest_status = 0;
  
  #status for services will be: 0=ok, 1=pending, 2=unknown, 3=warning, 4=critical
  nagios_services_highest_status = 0;

  nagios_hosts_message = ''
  nagios_services_message = ''

  if (hostsStatus['hoststatus'].respond_to? :each or servicesStatus['servicestatus'].respond_to? :each)

    hostsStatus['hoststatus'].each do |child|
      case child['current_state']
      when "0" #up
        nagios_hosts_count[0] += 1
      when "1" #down
        nagios_hosts_count[1] += 1
        nagios_hosts_message += "<p class='single-message-header'><i class='fa fa-exclamation-circle'></i><span class='servername'>" + child['alias'] + "</span><span class='detail'>HOST DOWN</span></p>"
        if nagios_hosts_highest_status < 3
          nagios_hosts_highest_status = 3
        end
      when "2" #unreachable
        nagios_hosts_count[2] += 1
        nagios_hosts_message += "<p class='single-message-header'><i class='fa fa-exclamation-triangle'></i><span class='servername'>" + child['alias'] + "</span><span class='detail'>HOST UNRECHABLE</span></p>"
        if nagios_hosts_highest_status < 2
          nagios_hosts_highest_status = 2
        end
      else #pending
        nagios_hosts_count[3] += 1
        nagios_hosts_message += "<p class='single-message-header'><i class='fa fa-question'></i><span class='servername'>" + child['alias'] + "</span><span class='detail'>HOST PENDING</span></p>"
        if nagios_hosts_highest_status < 1
          nagios_hosts_highest_status = 1
        end
      end
    end

    servicesStatus['servicestatus'].each do |child|
      case child['current_state']
      when "0" #ok
        nagios_services_count[0] += 1
      when "1" #warning
        nagios_services_count[1] += 1
        nagios_services_message += "<p class='single-message-header'><i class='fa fa-exclamation-triangle'></i><span class='servername'>" + child['host_alias'] + "</span><span class='detail'>" + child['display_name'] + "</span></p>"
        nagios_services_message += "<p class='single-message-body'>" + child['status_text'] + "</p>"
        if nagios_services_highest_status < 3
          nagios_services_highest_status = 3
        end
      when "2" #critical
        nagios_services_count[2] += 1
        nagios_services_message += "<p class='single-message-header'><i class='fa fa-exclamation-circle'></i><span class='servername'>" + child['host_alias'] + "</span><span class='detail'>" + child['display_name'] + "</span></p>"
        nagios_services_message += "<p class='single-message-body'>" + child['status_text'] + "</p>"
        if nagios_services_highest_status < 4
          nagios_services_highest_status = 4
        end
      when "3" #unknown
        nagios_services_count[3] += 1
        nagios_services_message += "<p class='single-message-header'><i class='fa fa-question'></i><span class='servername'>" + child['host_alias'] + "</span><span class='detail'>" + child['display_name'] + "</span></p>"
        nagios_services_message += "<p class='single-message-body'>" + child['status_text'] + "</p>"          
        if nagios_services_highest_status < 2
          nagios_services_highest_status = 2
        end
      else #pending
        nagios_services_count[4] += 1
        if nagios_services_highest_status < 1
          nagios_services_highest_status = 1
        end
     end
    end

    hoststatus = nagios_hosts_highest_status == 3 ? "red" : (nagios_hosts_highest_status == 2 ? "yellow" : (nagios_hosts_highest_status > 0 ? "grey" : "green"))
    servicestatus = nagios_services_highest_status == 4 ? "red" : (nagios_services_highest_status == 3 ? "yellow" : (nagios_services_highest_status > 0 ? "grey" : "green"))

    if nagios_services_count[0] == 0 and nagios_services_count[1] == 0 and nagios_hosts_count[0] == 0 and nagios_hosts_count[1] == 0
      if servicesStatus.length == 0 or hostsStatus.length == 0
        hoststatus = "error"
        servicestatus = "error"
      end
    end

    send_event('nagiosxihosts', { host_up: nagios_hosts_count[0], host_down: nagios_hosts_count[1], host_unreachable: nagios_hosts_count[2], host_pending: nagios_hosts_count[3], hoststatus: hoststatus })
    send_event('nagiosxiservices', { service_ok: nagios_services_count[0], service_warning: nagios_services_count[1], service_critical: nagios_services_count[2], service_unknown: nagios_services_count[3], service_pending: nagios_services_count[4], servicestatus: servicestatus })
    send_event('messages', { nagios_hosts: nagios_hosts_message, nagios_services: nagios_services_message}) 

  else #no data from nagios server
    send_event('nagiosxihosts', { host_up: 0, host_down: 0, host_unreachable:0, host_pending: 0, hoststatus: "error" })
    sleep(1)
    send_event('nagiosxiservices', {  service_ok: 0, service_warning: 0, service_critical: 0, service_unknown: 0, service_pending: 0,servicestatus: "error" })
    send_event('messages', { nagios_hosts: nagios_hosts_message, nagios_services: nagios_services_message}) 
  end

end