#!/usr/bin/env ruby
#
require 'json'

# %R|%a|%C|
# name|state|alloc/idle/other/total|

# %N|%E|%H|%O|
# nodes|reason|timestamp unavailable|cpu load|

def get_queues conf, queues, full, queues_list=nil
  extra = queues_list ? "-p #{queues_list.join(',')}" : ''
  IO.popen("#{conf[:sinfo_queues_cmd]} #{extra} -h -o '\%R|\%a|\%C|\%n|\%O|\%H|\%E'") do |io|
    io.each_line do |line|
      (part, state, part_stat, node, cpu_load, timestamp, reason) = line.split('|')
      if queues[part].nil?
        (alloc, idle, other, total) = part_stat.split '/'
        queues[part] = {
          state: state,
          nodes_total: total.to_i,
          nodes_alloc: alloc.to_i,
          nodes_idle:  idle.to_i,
          nodes_other: other.to_i,
          nodes: []
        }
      end
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

def get_tasks conf, full, queues_list=nil
  extra = queues_list ? "-p #{queues_list.join(',')}" : ''
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
    end
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
  tasks: []
}

conf = {
  sinfo_queues_cmd: 'sinfo',
  squeue_tasks_cmd: 'squeue',
  sinfo_nodes_cmd: 'sinfo',
}

get_queues(conf, queues, full, ['pascal', 'test','compute'])
get_tasks(conf, full, ['pascal', 'test','compute'])
#get_tasks(conf, full, ['pascal', 'test'])

STDOUT.write '{"queues": '
STDOUT.write queues.to_json
STDOUT.write ', "nodes": '
STDOUT.write full[:nodes].to_json
STDOUT.write ', "tasks": '
STDOUT.write full[:tasks].to_json
STDOUT.write '}'
