#!/usr/bin/env ruby
#

require 'json'
require 'savon'
require 'net/http'
require 'net/https'
require 'uri'
require 'ostruct'

YEAR_KEY=ENV['YEAR_KEY'] || '1234567890'
YEAR_SRV=ENV['YEAR_SRV'] || 'https://my.soap.server.insert-here.wsdl'
GET_SLURM_LONG='ssh -qi /home/serg/.ssh/slurm_json root@jd-vm'

def get_long_slurm

  json_text = IO.popen(GET_SLURM_LONG){|io| io.read}
  data={}
  begin
    json = JSON.parse json_text #.gsub("'",'"')
    json.each{|qinfo|
      case qinfo['_id']
      when 'total_jobs'
        data['totalTasks'] = qinfo['count']
      when 'accounts'
        data['userCount'] = qinfo['count']
      when 'projects'
        data['projectsCount'] = qinfo['count']
      when 'queue_total_avg'
        data['avgQueueLength'] = qinfo['waiting']
      when 'wait_time'
        data['avgQueueWaitingTime'] = qinfo['avg']
      end
    }
  rescue => e
    warn "Cannot read long term slurm data: #{e.message}"
    data={}
  end
  data
end

def send_long_slurm_soap server, data
  return if data.keys.count == 0
  client = Savon.client(
    wsdl: server,
    unwrap: true,
    convert_request_keys_to: :none,
  )
  begin
    msg = { 'Date' => Time.now.to_i, 'API' => YEAR_KEY, data: {'Supercompyearinfo' => data}}
    #warn msg.inspect
    response = client.call(:send_stat_data,  message: msg)
    response.http
  rescue => e
    OpenStruct.new(code: 999, body: e.message)
  end
end

res = send_long_slurm_soap(YEAR_SRV, get_long_slurm)
if res.code.to_s == '200'
  #warn "OK: #{res.body}"
else
  warn "long term slurm: #{res.code} #{res.body}"
end
