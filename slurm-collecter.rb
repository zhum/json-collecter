#!/usr/bin/env ruby
#

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

def expand list
  list
end

def get_tasks conf, full, queues_list=nil
  extra = queues_list ? "-p #{queues_list.join(',')}" : ''
  #warn ">>>>> #{conf[:squeue_tasks_cmd]} #{extra} -h -o '\%i|\%S\%e|\%U|\%t|\%v|\%N|\%p|\%r|\%|\%o'"
  IO.popen("#{conf[:squeue_tasks_cmd]} #{extra} -h -o '\%i|\%S|\%e|\%U|\%t|\%v|\%n|\%p|\%r|\%o'") do |io|
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
        nodes: expand(nodeslist),
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
  tasks: [
  ]
}

conf = {
  sinfo_queues_cmd: 'sinfo',
  squeue_tasks_cmd: 'squeue',
  sinfo_nodes_cmd: 'sinfo',
}

get_queues(conf, queues, full, ['pascal', 'test'])
get_tasks(conf, full, ['pascal', 'test'])

puts "QUEUES:"
puts queues.inspect
puts "FULL"
puts full.inspect
