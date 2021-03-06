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
GET_SLURM_LONG='TERM=vt100 ssh -qTi /home/serg/.ssh/slurm_json -o "BatchMode yes" root@jd-vm'

def get_long_slurm

  json_text = IO.popen(GET_SLURM_LONG){|io| io.read}
  data={}
  begin
    json = JSON.parse json_text #.gsub("'",'"')
    json.each{|qinfo|
      case qinfo['_id']
      when 'total_jobs'
        data['totalTasks'] = qinfo['count']
      when 'total_accounts'
        data['userCount'] = qinfo['count']
      when 'total_projects'
        data['projectsCount'] = qinfo['count']
#      when 'queue_total_avg'
#        data['avgQueueLength'] = qinfo['waiting']
#      when 'wait_time'
#        data['avgQueueWaitingTime'] = qinfo['avg']
      when 'wait_time'
        data['avgQueueWaitingTime'] = qinfo['avg_by_queue']['compute']
      when 'jobs_waiting'
        data['avgQueueLength'] = qinfo['avg_by_queue']['compute']
      end
    }
  rescue => e
    warn "Cannot read long term slurm data: #{e.message} (json=#{json_text})"
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

#warn get_long_slurm.inspect
res = send_long_slurm_soap(YEAR_SRV, get_long_slurm)
if res.code.to_s == '200'
  #warn "OK: #{res.body}"
else
  warn "long term slurm: #{res.code} #{res.body}"
end
