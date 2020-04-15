#!/usr/bin/env ruby
#

require 'json'
#require 'savon'
require 'net/http'
require 'net/https'
require 'uri'

CLUSTER=ENV['CLUSTER'] || 'lomonosov-X'
API_KEY=ENV['API_KEY'] || '1234567890'
SOAP_SRV=ENV['SOAP_SRV'] || 'https://my.soap.server.insert-here/wsdl'
JSON_SRV=ENV['JSON_SRV'] || 'https://my.soap.server.insert-here/wsdl'

PREFIX = ENV['PREFIX'] || '/opt/slurm/bin'
conf = {
  sinfo_queues_cmd: ENV['SINFO'] || "#{PREFIX}/sinfo",
  squeue_tasks_cmd: ENV['SQUEUE'] || "#{PREFIX}/squeue",
  sinfo_nodes_cmd:  ENV['SINFO'] || "#{PREFIX}/sinfo",
  queues: ENV['QUEUES'] ? ENV['QUEUES'].split : ['test']
}

# %R|%a|%C|
# name|state|alloc/idle/other/total|

# %N|%E|%H|%O|
# nodes|reason|timestamp unavailable|cpu load|

def get_queues conf, queues, full
  extra = conf[:queues] ? "-p #{conf[:queues].join(',')}" : ''
  queues['all'] ||= { nodes_total: 0, nodes_alloc: 0, nodes_idle: 0, nodes_other: 0, state: 'up'}
  all_q={}
  IO.popen("#{conf[:sinfo_queues_cmd]} #{extra} -h -o '\%R|\%a|\%C|\%n|\%O|\%H|\%E'") do |io|
    io.each_line do |line|
      (part, state, part_stat, node, cpu_load, timestamp, reason) = line.split('|')
      next unless conf[:queues].include? part 
      if all_q[part].nil?
        IO.popen("#{conf[:sinfo_queues_cmd]} -p #{part} -h -o '\%F'") do |q|
          q.each_line do |l|
            all_q[part]=l.chomp
          end
        end
      end
      if queues[part].nil?
        #warn "ipart=#{part} part_stat=#{part_stat}"
        #(alloc, idle, other, total) = part_stat.split '/'
        (alloc, idle, other, total) = all_q[part].split '/'
        queues[part] = {
          state: state,
          nodes_total: total.to_i,
          nodes_alloc: alloc.to_i,
          nodes_idle:  idle.to_i,
          nodes_other: other.to_i,
          nodes: []
        }
        queues['all'][:nodes_total]+=total.to_i
        queues['all'][:nodes_alloc]+=alloc.to_i
        queues['all'][:nodes_idle]+=idle.to_i
        queues['all'][:nodes_other]+=other.to_i
      end
      #if queues[part].nil?
      #  (alloc, idle, other, total) = part_stat.split '/'
      #  queues[part] = {
      #    state: state,
      #    nodes_total: total.to_i,
      #    nodes_alloc: alloc.to_i,
      #    nodes_idle:  idle.to_i,
      #    nodes_other: other.to_i,
      #    nodes: []
      #  }
      #end
      queues[part][:nodes] << node
      full[:nodes][:cpu_load] ||= {}
      full[:nodes][:cpu_load][node] = cpu_load.to_f
    end
  end

  IO.popen("#{conf[:sinfo_nodes_cmd]} #{extra} -h -o '\%n|\%t'") do |io|
    io.each_line do |line|
      (name,state) = line.chomp.split '|'
      case state.sub('*', '')
      when 'alloc', 'comp', 'idle'
        full[:nodes][:alive] << name
      when 'drain', 'drng', 'fail', 'failg', 'maint', 'mix'
        full[:nodes][:drain] << name
      when 'resv'
        full[:nodes][:reserved] << name
      else
        full[:nodes][:off] << name
      end
    end 
  end

end


def interval prefix, str ,postfix
#  warn ">>#{prefix}; #{str};"
  if /(\d+)-(\d+)/.match str
    w="%0#{$1.size}d"
    $1.to_i.upto($2.to_i).map {|i| "#{prefix}#{w % i}#{postfix}"}.join ','
  else
    "#{prefix}#{str}"
  end
end

def unslurm str
  str = ",#{str},"
  while /([^\[]*),([^,\[]+)(\[[^\]]+\])([^,]*),(.*)/.match str
  #  warn "!! (#{$1})(#{$2})(#{$3})(#{$4})(#{$5})"
    start=$1
    prefix=$2
    m=$3
    postfix=$4
    fin=$5
    list=m[1..-2].split ','
    result=list.map { |str| ",#{interval(prefix,str,postfix)}" }.join ','
    str="#{start},#{result},#{fin}"
  #  warn "## #{args}"
  end
  str.split(',').reject{|x| x.length<1}
end

def get_tasks conf, full
  extra = conf[:queues] ? "-p #{conf[:queues].join(',')}" : ''
  IO.popen("#{conf[:squeue_tasks_cmd]} #{extra} -h -o '\%i|\%S|\%e|\%U|\%t|\%v|\%N|\%P|\%r|\%o'") do |io|
    io.each_line do |line|
      (id,starttime,endtime,uid,state,reservation,nodeslist,part,reason,cmd) = line.chomp.split '|'
      #warn id
      
      full[:tasks] << {
        id: id.to_i,
        starttime: starttime,
        endtime: endtime,
        uid: uid.to_i,
        state: state,
        reservation: reservation,
        nodes: unslurm(nodeslist),
        partition: part,
        reason: reason,
        command: cmd
      }
      full[:tasks_by_queue][part]||={running: 0, queued: 0, other: 0}
      st = state=='R' ? :running : state=='PD' ? :queued : :other
      full[:tasks_by_queue][part][st]+=1
      full[:tasks_by_queue]['all'][st]+=1
    end
  end
end

#def send_soap server, queues, full
#  client = Savon.client(wsdl: server, unwrap: true)
#  warn client.operations
#  data = []
#
#  queues.each do |q,v|
#    {'total' => :nodes_total, 'free' => :nodes_idle, 'allocated' => :nodes_alloc, 'other' => :nodes_other}.each {|soap_name,name|
#      data << {
#        SuperComp: {
#          SCName: CLUSTER,
#          Section: q,
#          ParName: 'nodes',
#          ParType: soap_name,
#          Count: v[name]
#        }
#      }
#    }
#  end
#  full[:tasks_by_queue].each do |q,v|
#    [:running,:queued,:other].each{|t|
#      data << {
#        SuperComp: {
#          SCName: CLUSTER,
#          Section: q,
#          ParName: 'tasks',
#          ParType: t,
#          Count: v[t]
#        }
#      }
#    }
#  end 
#  begin
#    msg = { 'Date' => Time.now.to_i, 'API' => API_KEY, data: data}
#    warn "MSG: #{msg.inspect}"
#    #response = client.call(:send_stat_data,  message: { 'Date' => Time.now.to_i, 'API' => API_KEY, data: {"ns0:Supercomp" => data}})
#    response = client.call(:rcv_request,  message: {'srv_request' => { 'Date' => Time.now.to_i, 'API' => API_KEY, data: data}})
#  rescue => e
#    warn "Err: #{e.class} #{e.message} #{e.inspect}"
#  end
#end

def send_json server, queues, full
  uri = URI.parse(server)
  req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')

  data = {nodes: {}, tasks: {}}

  queues.each do |q,v|
    data[:nodes][q]||={}
    {'total' => :nodes_total, 'free' => :nodes_idle, 'allocated' => :nodes_alloc, 'other' => :nodes_other}.each {|json_name,name|
      data[:nodes][q][json_name]=v[name]
    }
  end
  full[:tasks_by_queue].each do |q,v|
    data[:tasks][q]||={}
    [:running,:queued,:other].each{|t|
      data[:tasks][q][t]=v[t]
    }
  end 
  begin
    req.body = {key: API_KEY, data: {CLUSTER => data}}.to_json
    #warn "-->\n#{req.body}"
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    response = http.request(req)
  rescue => e
    warn "Err: #{e.class} #{e.message} #{e.inspect}"
  end
end

queues = {}
full = {
  nodes: {
    alive: [],
    off: [],
    drain: [],
    reserved: [],
    cpu_load: {}
  },
  tasks: [],
  tasks_by_queue: { 'all' => {running: 0, queued: 0, other: 0}}
}

#conf = {
#  sinfo_queues_cmd: '/opt/slurm/15.08.1/bin/sinfo',
#  squeue_tasks_cmd: '/opt/slurm/15.08.1/bin/squeue',
#  sinfo_nodes_cmd: '/opt/slurm/15.08.1/bin/sinfo',
#}

#get_queues(conf, queues, full, ['pascal', 'test','compute'])
#get_tasks(conf, full, ['pascal', 'test','compute'])
get_queues(conf, queues, full)
get_tasks(conf, full)
#
#warn send_soap(SOAP_SRV,queues,full)
res = send_json(JSON_SRV,queues,full)
unless res.code=='200'
  warn "#{res.code} #{res.body}"
end
out = ARGV[0].nil? ?
  STDOUT :
  File.open(ARGV[0], "w")

out.write '{"time": "'
out.write Time.now.strftime "%Y-%m-%dT%H:%M:%S"
out.write '","queues": '
out.write queues.to_json
out.write ', "nodes": '
out.write full[:nodes].to_json
out.write ', "tasks": '
out.write full[:tasks].to_json
out.write '}'
