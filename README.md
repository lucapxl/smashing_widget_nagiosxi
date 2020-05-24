# NagiosXI Widget for [Smashing](https://smashing.github.io)

[Smashing](https://smashing.github.io) widget to monitor the status of **Hosts** and **Services** from Nagios XI.
The numbers in the tiles represent the following:

* Hosts: OK/DOWN/UNREACHABLE
* Services: OK/UNKNOWN/WARNING/CRITICAL

## Example

![hosts](https://raw.githubusercontent.com/lucapxl/smashing_widget_nagiosxi/master/images/hosts-critical.png)
![hosts2](https://raw.githubusercontent.com/lucapxl/smashing_widget_nagiosxi/master/images/hosts-ok.png)

![services](https://raw.githubusercontent.com/lucapxl/smashing_widget_nagiosxi/master/images/services-critical.png)
![services2](https://raw.githubusercontent.com/lucapxl/smashing_widget_nagiosxi/master/images/services-warning.png)
![services3](https://raw.githubusercontent.com/lucapxl/smashing_widget_nagiosxi/master/images/services-ok.png)

## Installation and Configuration
This widget uses `open-uri` and `json`. make sure to add them in your dashboard Gemfile
```Gemfile
gem 'open-uri'
gem 'json'
```

and to run the update command to download and install them.

```bash
$ bundle update
```

Create a ```nagiosxi``` folder in your ```/widgets``` directory and clone this repository inside it. make a symolic link of the file ```jobs/nagiosxi.rb``` in the ```/jobs/``` directory of your dashboard. For example, if your smashing installation directory is in ```/opt/dashboard/``` you would run this:
```Shell
$ ln -s /opt/dashboard/widgets/nagiosxi/jobs/nagiosxi.rb /opt/dashboard/jobs/nagiosxi.rb
```

configure `nagiosxi.rb` job file for your environment:

```ruby
apiKey = 'xxxxxxx' # The API Key generated in your Nagios XI
nagiosHOST = 'your.nagiosxihost.name' # IP Address or Hostname of your Nagios XI server
```

add the tiles in your dashboard .erb file

```html
    <li data-row="2" data-col="2" data-sizex="1" data-sizey="1">
      <div data-id="nagiosxi" data-view="Nagiosxi" data-title="Infrastructure"></div>
    </li>
```

## [Messages](https://github.com/lucapxl/smashing_widget_messages) widget integration

Since this widget only displays the status of the Services and Hosts, I had the need to visualize the details in case the status was not OK. The `nagiosxi.rb` job is setup in a way to send detailed information to the widget [Messages](https://github.com/lucapxl/smashing_widget_messages) I developed to organize "messages" of other widgets in a single box.

![example1](https://raw.githubusercontent.com/lucapxl/smashing_widget_messages/master/images/messages-1.png)

## License

Distributed under the MIT license
