#!/usr/bin/ruby

# Alex Pilafian - 2014/12 

#Solves the Traveling Salesman problem using the Branch and Bound technique.

#This technique gives an exact solution to the problem in O((n-1)!) time. 

require 'matrix' #also requires Vector

#adds some math related methods to the Matrix class that the "Branch and Bound" technique requires.
class Matrix

  #for debugging :)
  def pretty_print
    self.to_a.each {|r| puts r.inspect}
    return nil
  end

  #returns a new Matrix which is the row-reduced form of this one.
  #subtracts the values of each row by that row's minimum
  def row_reduction
    reduction_ar = Array.new

    #get 2d array from matrix for updating...
    reduced_matrix_ar = self.to_a

    #for each row in this matrix...
    (0..(self.row_size-1)).each do |i|
      row = self.row(i)

      #this is the minimum value found in this row...
      minval = row.min

      #add this minimum value to the return object
      reduction_ar.push(minval)

      #set the row to the reduced version
      reduced_matrix_ar[i] = row.to_a.collect do |row_el|
        #skips rows where calculations involve infinity.
        next(Float::INFINITY) if (row_el.equal? Float::INFINITY or minval.equal? Float::INFINITY)

        #the actual reduction happens here
        row_el - minval
      end
    end

    return {
      :matrix=>Matrix[*reduced_matrix_ar], 
      :reduction=>reduction_ar.reject{|el| el.equal? Float::INFINITY}
    }
  end

  #returns a new Matrix which is the column-reduced form of this one.
  #subtracts the values of each row by that column's minimum
  def column_reduction

    reduction_ar = Array.new
    reduced_matrix_ar = self.to_a

    #for each column...
    (0..(self.column_size-1)).each do |j|
      col = self.column(j)
      minval = col.min

      reduction_ar.push(minval)

      #loop through each row to to update this column
      (0..(self.row_size-1)).each do |i|
        val = reduced_matrix_ar[i][j]

        #Skip doing calculations with infinity.
        next(Float::INFINITY) if (val.equal? Float::INFINITY or minval.equal? Float::INFINITY)

        #sets the column value for this row
        reduced_matrix_ar[i][j] = val - minval
      end
    end

    return {
      :matrix=>Matrix[*reduced_matrix_ar], 
      :reduction=>reduction_ar.reject{|el| el.equal? Float::INFINITY}
    }
  end
  
  def reduction
    #gets the total reduction of this matrix, by taking the row reduction and then the column reduction
    rowred_result_obj = self.row_reduction

    #sums the reduction minimums returned by the row reduction
    total_reduction = rowred_result_obj[:reduction].inject(0){|memo, x| memo += x}

    #take the column reduction of the matrix returned by the row reduction...
    colred_result_obj = rowred_result_obj[:matrix].column_reduction

    #sums the reduction minimums returned by the column reduction
    total_reduction += colred_result_obj[:reduction].inject(0){|memo, x| memo += x}
    
    reduction_mtx = colred_result_obj[:matrix]

    #return the data
    {:matrix=>reduction_mtx, :total_reduction=>total_reduction}
  end
end

#this is the Node class.
#Each Node represents the possibility of traveling from one city to another.

#Specifically, the possibility of traveling from the city of the parent node
#to the one saved in this node's city_id.

#Each node has a base cost, representing the minimum possible cost of the
#rest of the trip, after this leg of the journey.
class Node
  include Comparable
  
  attr_accessor :children #Node[]
  attr_accessor :parent #Node
  attr_accessor :city_id #Integer
  
  attr_accessor :base_cost #Float
  attr_accessor :cost_matrix #Matrix
  attr_accessor :reduced_cost_matrix #Matrix
  
  attr_accessor :visited_this_tour #Integer[]

  def initialize city_id, parent=nil
    @city_id = city_id
    @parent = parent
    @visited_this_tour = Array.new
    @children = Array.new

    #only do this for nodes which are not ROOT
    if(not @parent.nil?)
      #set the cost matrix from the parent node's reduced cost matrix.
      self.set_cost_matrix(parent.reduced_cost_matrix.clone)
      @visited_this_tour = parent.visited_this_tour.clone

      #calculate this node's base cost
      self.calculate_base_cost!
    end

    #add this Node's city ID to this tour
    @visited_this_tour << @city_id

  end

  def set_cost_matrix(parent_rcm)
    @cost_matrix = parent_rcm

    if(@parent) #only do this if not the ROOT node

      rcm_2d_ar = @cost_matrix.to_a

      #first set the row representing the parent city_id to infinity
      #(represents that we can no longer go from this city since we just did)
      rcm_2d_ar[@parent.city_id] = Array.new(@cost_matrix.row_size, Float::INFINITY)

      #now set the column of the incoming city (this node) to infinity
      #(represents that we can no longer come to this city since we just did)
      (0..(@cost_matrix.row_size-1)).each do |i|
        rcm_2d_ar[i][self.city_id] = Float::INFINITY
      end

      #finally, ensure that this entry in the first column is blocked
      #(represents that we do not want to come back to the first node from this one)
      rcm_2d_ar[self.city_id][1] = Float::INFINITY

      @cost_matrix = Matrix[*rcm_2d_ar]
    end
  end

  #Creates the children for this node, calculating travel to all possible nodes that have not yet been visited.
  def create_children!
    all_cities = TSP.cities.keys

    #rejects the cities which have already been visited
    all_cities.reject!{|city_id| self.visited_this_tour.include?(city_id)}
    all_cities.each do |city_id|
      @children << Node.new(city_id, self)
    end
  end

  #Calculates the base cost from:
  # 1) the total reduction of the cost matrix,
  # 2) the parent's base cost, and
  # 3) the indicated cost of this leg of the journey, sourced from the parents' reduced cost matrix.
  def calculate_base_cost!
    result_obj = self.cost_matrix.reduction

    @base_cost = result_obj[:total_reduction]
    if(self.parent)
      @base_cost += self.parent.base_cost + self.parent.reduced_cost_matrix[self.parent.city_id, self.city_id]
    end

    @reduced_cost_matrix = result_obj[:matrix]
  end

  #Nodes are comparable based on their base_cost attribute
  def <=>(another_node)
    return self.base_cost <=> another_node.base_cost
  end
end

class TSP
  #maintains the @@cities object as a class variable
  #this holds the parsed data from input.
  @@cities = {}

  def self.cities
    @@cities
  end

  attr_accessor :root_node
  attr_accessor :adj_matrix #adjacency matrix

  #reads the cities from the specified input.
  #if no input file is specified as an argument, it takes the input data from STDIN
  def read_cities_from_input!
    file = nil

    if(ARGV[0] and not ARGV[0].empty?)
      file = File.open(ARGV[0], "r")
    else
      file = File.open("cities.txt", "r")
    end

    file.each_with_index do |line, idx|
        line_ar = line.split("\t")
        #Loads each line into an object with a name and a location vector with latitude and longitude
        @@cities[idx] = {:name=>line_ar[0], :location=>Vector[line_ar[1].to_f, line_ar[2].to_f]}
    end
  end

  #Calculates a matrix of the distances between all cities. Stores in @adj_matrix
  def calculate_adjacency_matrix!
    @adj_matrix = Matrix.build(@@cities.length) do |i,j|

      #set the adjacency matrix to infinity for travelling to the same city; this should be impossible.
      if(i == j)
        next Float::INFINITY
      end

      #calculates the distance between city i and city j using the Vector#magnitude method
      next (@@cities[i][:location] - @@cities[j][:location]).magnitude
    end
  end

  #main TSP init method, just parses the input
  def initialize

    @@cities ||= Hash.new

    if(@@cities.empty?)
      self.read_cities_from_input!
    end

  end

  #Logic for actually solving the TSP and printing the answer.
  def solve!
    #calculates the initial adjacency matrix
    self.calculate_adjacency_matrix!

    #create the root node, with city ID 0 (for Beijing)
    self.root_node = Node.new(0)
    self.root_node.set_cost_matrix(self.adj_matrix) #set the cost matrix to the adjacency matrix

    #calculate the base cost manually (usually would happen during init but ROOT lacks a parent)
    self.root_node.calculate_base_cost!
    node = self.root_node

    #keep creating child nodes and selecting the minimum from the next level,
    #repeating until all cities have been visited.
    while(node.visited_this_tour.size < @@cities.size)
      node.create_children!

      best_node = node.children.min
      node = best_node
    end

    #print the results!
    node.visited_this_tour.each do |city_id|
      puts @@cities[city_id][:name]
    end

  end
  
end

#Instantiate global TSP object
$tsp = TSP.new

#run solver!
$tsp.solve!