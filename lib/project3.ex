defmodule Project3 do

  def func(args \\ []) do
  options = [switches: [file: :string],aliases: [f: :file]]
    {_,ar2,_} = OptionParser.parse(args,options)

  num = String.to_integer(List.first(ar2))
  req = String.to_integer(List.last(ar2))

  generate(num,req)
end
def generate(num,req) do
    li = Enum.map(1..num,&(&1))

#................... Generate Children ..................................................
    {:ok,pid}=Node1.Supervisor.start_link(num)
    IO.inspect(pid) #supervisor's pid
    list=Supervisor.which_children(pid)
    child_list=(for x <- list, into: [] do
                {_,cid,_,_}=x
                cid
                 end)
    child_list = Enum.reverse(child_list)

#..........................................................................................

#..................Assign NodeIds..........................................................
    hashlist = Enum.map(li,fn(x)->:crypto.hash(:sha,Integer.to_string(x))|>Base.encode16 end)
    Enum.each(li,fn(x)->Actor1.hashfun(Enum.at(child_list,x-1),Enum.at(hashlist,x-1)) end)
    Enum.each(child_list,fn(x)->Actor1.initneighmap(40,16,x) end)
    nodelist = Enum.sort(hashlist)
    lis = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
    nodes = Enum.map(lis,fn(x)->groupnodelist(nodelist,x) end)
    nodes = %{"0"=>Enum.at(nodes,0),"1"=>Enum.at(nodes,1),"2"=>Enum.at(nodes,2),"3"=>Enum.at(nodes,3),"4"=>Enum.at(nodes,4),"5"=>Enum.at(nodes,5),"6"=>Enum.at(nodes,6),"7"=>Enum.at(nodes,7),"8"=>Enum.at(nodes,8),"9"=>Enum.at(nodes,9),"A"=>Enum.at(nodes,10),"B"=>Enum.at(nodes,11),"C"=>Enum.at(nodes,12),"D"=>Enum.at(nodes,13),"E"=>Enum.at(nodes,14),"F"=>Enum.at(nodes,15)}

#..................Assign Map....................................................
    nodepids = Enum.map(child_list,fn(x)->id = Map.get(Actor1.get_state(x),:nodeid)
                                                {String.to_atom(id),x} end)
    Enum.each(child_list,fn(x)->Actor1.assignmap(x,nodes,nodepids) end)
#.....................StartTapestry.......................................................
    Enum.each(child_list,fn(x)->Actor1.starttapestry(x,req,nodelist) end)
    :timer.sleep(5000)
    maxhop = Enum.map(child_list,fn(x)->Map.get(Actor1.get_state(x),:maxhop) end)|> Enum.max()
    IO.puts "Maximum Hop    #{maxhop}"
end



def groupnodelist(nodelist,y) do
    res = Enum.map(nodelist,fn(x)->groupnode(x,y) end)|>Enum.uniq()
    res= res--[nil]
    res
end

def groupnode(nodeid,x) do
    if String.at(nodeid,0) == x do
        nodeid
    else
        nil
    end
end

end




defmodule Node1.Supervisor do
    use Supervisor
    def start_link(n) do
        {myInt, _} = :string.to_integer(to_charlist(n))
        Supervisor.start_link(__MODULE__,n )
    end

    def init(myInt) do
       children =Enum.map(1..myInt, fn(s) ->
            #IO.puts "I am in supervisor init"
            worker(Actor1,[s],[id: "#{s}"])
            end)
        supervise(children, strategy: :one_for_one)
    end
end
###############################################################################################################################################

defmodule Actor1 do
    use GenServer
    def start_link(index) do
        GenServer.start_link(__MODULE__,index)
    end


    def init(index) do
        state = %{:node=>index,:nodeid=>index,:pid=>self(),:neighmap=>[],:rows=>[],:nodepids=>[],:maxhop=>0}
        {:ok,state}
    end

    def initneighmap(i,j,pid) do
        GenServer.cast(pid,{:initnode,i,j})
    end

    def hashfun(pid,hash) do
        GenServer.cast(pid,{:updatehash,hash})
    end

    def get_state(pid) do
        GenServer.call(pid, {:state})
    end

    def assignmap(pid,nodelist,nodepids) do
        lis = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
        state = get_state(pid)
        nodeid = Map.get(state,:nodeid)
        levellist  = nodelist[String.at(nodeid,0)]
        nearlist = Enum.map(lis,fn(x)-> cond do
                                            x<String.at(nodeid,0)->List.last(nodelist[x])
                                            x==String.at(nodeid,0)->"nil"
                                            x>String.at(nodeid,0)->List.first(nodelist[x])
                                            end end)
        genmap(pid,levellist,nearlist,nodepids)
    end

    def genmap(pid,levellist,nearlist,nodepids) do
        Enum.each(0..40,fn(x)->GenServer.cast(pid,{:genmap,levellist,nearlist,nodepids,x}) end)
        #IO.inspect get_state(pid)
    end

    def get_values(levellist,level,id) do
        lis = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"]
        #IO.puts "check"
        levelnodes = Enum.map(levellist,fn(y)->if String.slice(id,0..level-1)==String.slice(y,0..level-1) and String.slice(id,0..level)!=String.slice(y,0..level) do
                                        y
                                    else
                                        nil
                                    end end)|>Enum.uniq()
        levelnodes = levelnodes--[nil]
        ln = Enum.map(lis,fn(x)->val = Enum.map(levelnodes,fn(y)->if String.at(y,level)==x do
                                                            y
                                                        else
                                                            nil
                                                        end end)|>Enum.uniq()
                                            if val==[nil] do
                                                nil
                                            else
                                                val--[nil]
                                            end end)
        ln = Enum.map(ln,fn(x)->if x != nil do
                                    List.first(x)
                                else
                                    nil end end )
    end

    def routetonode(sourcenode,destnode,hop,pid) do
        #IO.puts "check1"
        GenServer.cast(pid,{:routetonode,sourcenode,pid,destnode,hop})
    end

    def get_nearnode(destnode,neighmap,nodeid) do
        level = Enum.map(0..String.length(nodeid),fn(x)->if String.at(nodeid,x)!=String.at(destnode,x), do: x end)|>Enum.uniq()
        level = level--[nil]|> List.first()#|>Integer.to_string()
        #IO.puts level
        nearlist = Enum.at(neighmap,level)|>Enum.uniq()
        nearlist = nearlist--[nil]
        nearnode = Enum.map(nearlist,fn(x)-> if String.at(x,level)==String.at(destnode,level), do: x end)|>Enum.uniq()
        nearnode = List.last(nearnode--[nil])
        #IO.puts "NExtnode       #{nearnode}"
        nearnode
    end

    def starttapestry(pid,req,nodelist) do
        sourcenode = Map.get(get_state(pid),:nodeid)
        destnodes = Enum.map(1..req,fn(_)->Enum.random(nodelist--[sourcenode]) end)
        for i<-destnodes do
            routetonode(sourcenode,i,0,pid)
            #:timer.sleep(1000)
        end
        #Enum.each(destnodes,fn(x)->routetonode(sourcenode,x,0,pid) end)
    end



    def handle_cast({:routetonode,sourcenode,sourcenodepid,destnode,hop},state) do
        nodepids = Map.get(state,:nodepids)
        neighmap = Map.get(state,:neighmap)
        #IO.inspect state
        nodeid   = Map.get(state,:nodeid)
        #IO.inspect nodeid
        nearnode = get_nearnode(destnode,neighmap,nodeid)
        nearnodepid = nodepids[String.to_atom(nearnode)]
        if nearnode == destnode or sourcenode== destnode do
            GenServer.cast(sourcenodepid,{:recievehop,hop+1})
            #IO.puts "#{sourcenode}      #{destnode}      #{hop}"
        else
            nearnodepid = nodepids[String.to_atom(nearnode)]
            GenServer.cast(nearnodepid,{:routetonode,sourcenode,sourcenodepid,destnode,hop+1})
        end
        {:noreply,state}
    end

    def handle_cast({:recievehop,hop},state) do
        maxhop = max(Map.get(state,:maxhop),hop)
        state = Map.put(state,:maxhop,maxhop)
        {:noreply,state}
    end

    def handle_cast({:genmap,levellist,nearlist,nodepids,level},state) do
        nodeid = Map.get(state,:nodeid)
        neighmap = Map.get(state,:neighmap)
        state = Map.put(state,:nodepids,nodepids)
        if level == 0 do
            neighmap = List.update_at(neighmap,0,&(&1=nearlist))
            state = Map.put(state,:neighmap,neighmap)
            #IO.inspect(levellist)
            {:noreply,state}
        else
            neighmap = List.update_at(neighmap,level,&(&1=get_values(levellist,level,nodeid)))
            state = Map.put(state,:neighmap,neighmap)
            {:noreply,state}
        end
        #IO.inspect state

    end

    def handle_cast({:initnode,i,j},state) do
        rows = Enum.map(0..i-1,fn(x)->x end)
        cols = Enum.map(0..j-1,fn(_)->"nil" end)
        neighmap = Enum.map(rows,fn(x)->{String.to_atom("level"<>Integer.to_string(x)),cols} end)
        state = Map.put(state,:neighmap,neighmap)
        state = Map.put(state,:rows,rows)
        {:noreply,state}
    end

    def handle_cast({:updatehash,hash},state) do
        state = Map.put(state,:nodeid,hash)
        {:noreply,state}
    end

    def handle_call({:state},_from,state) do
        {:reply,state,state}
    end

    def addnode(i,j,pid,nodelist,nodepids) do
        initneighmap(i,j,pid)
        assignmap(pid,nodelist,nodepids)
        IO.inspect Map.get(get_state(pid),:neighmap)
    end

end

    Project3.func(System.argv)
