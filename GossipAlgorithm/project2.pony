use "collections"
use "random"
use "time"

actor Main
  new create(env: Env) =>
    try
      let args = env.args
      if args.size() != 4 then
        env.out.print("Usage: project2 numNodes topology algorithm")
        return
      end

      let num_nodes = args(1)?.usize()?
      let topology = args(2)?
      let algorithm = args(3)?

      env.out.print("Main Process started")

      let network = Network(num_nodes, topology, algorithm, env)
      network.start()
    else
      env.out.print("Invalid arguments")
    end

actor Network
  let nodes: Array[Node tag]
  let topology: String
  let algorithm: String
  let env: Env
  let rand: Random
  var start_time: U64
  var converged_count: USize = 0

  new create(num_nodes: USize, topology': String, algorithm': String, env': Env) =>
    nodes = Array[Node tag](num_nodes)
    topology = topology'
    algorithm = algorithm'
    env = env'
    rand = Rand(Time.nanos().u64())
    start_time = 0

    env.out.print("Server requested for Topology " + topology)

    for i in Range(0, num_nodes) do
      nodes.push(Node(i.u64(), this, env))
    end

    match topology
    | "full" => try create_full_topology()? else env.out.print("Error creating full topology") end
    | "3D" => try create_3d_topology()? else env.out.print("Error creating 3D topology") end
    | "line" => try create_line_topology()? else env.out.print("Error creating line topology") end
    | "imp3D" => try create_imperfect_3d_topology()? else env.out.print("Error creating imperfect 3D topology") end
    else
      env.out.print("Invalid topology")
    end

  be start() =>
    start_time = Time.nanos()
    env.out.print("Server requested for randomization for actors: " + nodes.size().string())
    try
      let starter = nodes(rand.int(nodes.size().u64()).usize())?
      starter.get_string({(s: String) => env.out.print("gossip actor - " + s) })
      match algorithm
      | "gossip" => starter.start_gossip()
      | "push-sum" => starter.start_push_sum()
      else
        env.out.print("Invalid algorithm")
      end
    end

  be node_converged() =>
    converged_count = converged_count + 1
    if converged_count == 1 then
      let end_time = Time.nanos()
      let elapsed_time_ms: F64 = (end_time - start_time).f64() / 1000000.0  // Convert to milliseconds with decimal precision
      env.out.print("Convergence time: " + elapsed_time_ms.string() + " milliseconds")
    end


  // Add a helper method to retrieve a node from the array safely
  be get_node(index: USize, sender: Node tag, rumor: Bool = true, s: F64 = 0, w: F64 = 0) =>
    try
      let random_node = nodes(index)?
      if rumor then
        random_node.receive_rumor()
      else
        random_node.receive_push_sum(s, w)
      end
    end

  fun ref create_full_topology() ? =>
    let size = nodes.size()
    for i in Range(0, size) do
      let neighbors = recover val
        let arr = Array[USize](size - 1)
        var j: USize = 0
        while j < size do
          if i != j then
            arr.push(j)
          end
          j = j + 1
        end
        arr
      end
      nodes(i)?.set_neighbors(neighbors)
    end

  fun ref create_3d_topology() ? =>
    let size = nodes.size()
    let dim = (size.f64().pow(1.0/3.0)).ceil().usize()
    
    for i in Range(0, size) do
      let x = i % dim
      let y = (i / dim) % dim
      let z = i / (dim * dim)
      
      let neighbors = recover val
        let arr = Array[USize]
        if x > 0 then arr.push(((z*dim*dim) + (y*dim) + (x-1))) end
        if x < (dim - 1) then arr.push(((z*dim*dim) + (y*dim) + (x+1))) end
        if y > 0 then arr.push(((z*dim*dim) + ((y-1)*dim) + x)) end
        if y < (dim - 1) then arr.push(((z*dim*dim) + ((y+1)*dim) + x)) end
        if z > 0 then arr.push((((z-1)*dim*dim) + (y*dim) + x)) end
        if z < (dim - 1) then arr.push((((z+1)*dim*dim) + (y*dim) + x)) end
        arr
      end
      
      // Ensure neighbors are within bounds (0 <= neighbor < size)
      let valid_neighbors = recover val
        let arr = Array[USize]
        for neighbor in neighbors.values() do
          if neighbor < size then arr.push(neighbor) end
        end
        arr
      end
      
      nodes(i)?.set_neighbors(valid_neighbors)
    end

  fun ref create_line_topology() ? =>
    let size = nodes.size()
    for i in Range(0, size) do
      let neighbors = recover val
        let arr = Array[USize]
        if i > 0 then arr.push(i-1) end
        if i < (size - 1) then arr.push(i+1) end
        arr
      end
      nodes(i)?.set_neighbors(neighbors)
    end

  fun ref create_imperfect_3d_topology() ? =>
    create_3d_topology()?
    
    for i in Range(0, nodes.size()) do
      let random_neighbor = rand.int(nodes.size().u64()).usize()
      nodes(i)?.add_random_neighbor(random_neighbor)
    end

  be get_random_node(sender: Node tag) =>
    try
      let random_index = rand.int(nodes.size().u64()).usize()
      sender.receive_random_node(nodes(random_index)?)
    end
  
  be get_random_node_for_push_sum(sender: Node tag) =>
    try
      let random_index = rand.int(nodes.size().u64()).usize()
      sender.receive_random_node_for_push_sum(nodes(random_index)?)
    end

actor Node
  let _id: U64
  let _network: Network tag
  let _env: Env
  let rand: Random
  var _neighbors: Array[USize] val
  var _rumor_count: USize
  var _s: F64
  var _w: F64
  var _converged: Bool
  var _countchanges: USize = 0

  new create(id: U64, network: Network tag, env: Env) =>
    _id = id
    _network = network
    _env = env
    _neighbors = recover val Array[USize] end
    _rumor_count = 0
    _s = id.f64()
    _w = 1.0
    _converged = false
    rand = Rand(Time.nanos().u64())
    //_env.out.print("New Node created with ID " + _id.string())

  be get_string(cb: {(String)} iso) =>
    cb("Node(" + _id.string() + ")")

  be set_neighbors(neighbors: Array[USize] val) =>
    _neighbors = neighbors

  be add_random_neighbor(neighbor: USize) =>
    if (neighbor != _id.usize()) and (not _neighbors.contains(neighbor)) then
      let new_neighbors = recover val
        let arr = Array[USize](_neighbors.size() + 1)
        for n in _neighbors.values() do
          arr.push(n)
        end
        arr.push(neighbor)
        arr
      end
      _neighbors = new_neighbors
    end

  be start_gossip() =>
    _rumor_count = 1
    spread_rumor()  // No try block needed here

  be receive_rumor() =>
    _env.out.print("Actor has received the rumor " + _id.string())
    _rumor_count = _rumor_count + 1
    if _rumor_count < 10 then
      spread_rumor()  // No try block needed here
    elseif not _converged then
      _converged = true
      _env.out.print("The actor is converged " + _id.string())
      _network.node_converged()
    end

  fun ref spread_rumor() =>
    if _neighbors.size() > 0 then
      // _env.out.print("Neighbours in gossip - " + _id.string())
      // _env.out.print("Process - " + _id.string() + ", Neighbours - " + ",".join(_neighbors.values()))

      // Ensure that the random selection is within the valid bounds of _neighbors
      let rand_index = rand.int(_neighbors.size().u64()).usize()  // Randomly select an index from neighbors
      _env.out.print("Random neighbor index selected: " + rand_index.string())

      try
        let random_neighbor = _neighbors(rand_index)?
        _env.out.print("Selected neighbor: " + random_neighbor.string())
        _network.get_node(random_neighbor, this)
      else
        _env.out.print("Error selecting a random neighbor.")
      end
    end

  be start_push_sum() =>
    push_sum_step()  // No try block needed here


  be receive_push_sum(s': F64, w': F64) =>
    let old_ratio = _s / _w
    // _env.out.print("S is " + _s.string())
    // _env.out.print("The old ratio is: " + old_ratio.string())
    _s = _s + s'
    _w = _w + w'
    let new_ratio = _s / _w
    // _env.out.print("The new ratio is: " + new_ratio.string())
    let diff = (old_ratio - new_ratio).abs()
    // _env.out.print("Difference is: " + diff.string())

    if diff < 1e-10 then
        _countchanges = _countchanges + 1
    else
        _countchanges = 0
    end

    if _countchanges >= 3 then
        if not _converged then
            _converged = true
            _env.out.print("Convergence achieved for " + _id.string())
            _network.node_converged()
        end
    else
      push_sum_step()  // No try block needed here
    end

  fun ref push_sum_step() =>
    if _neighbors.size() > 0 then
      try
        let random_neighbor = _neighbors(Rand.int(_neighbors.size().u64()).usize())?
        // Ask the network to send the push-sum values to this neighbor
        _network.get_node(random_neighbor, this, false, _s / 2, _w / 2)
      else
        _env.out.print("Error selecting a random neighbor for push-sum.")
      end
    end


  be receive_random_node(random_node: Node tag) =>
    random_node.receive_rumor()

  be receive_random_node_for_push_sum(random_node: Node tag) =>
    //_env.out.print("HELLO** S IS"+_s.string())
    //_env.out.print("HELLO** W IS"+_w.string())
    _s = _s / 2
    _w = _w / 2
    random_node.receive_push_sum(_s, _w)