#!/usr/bin/ruby

# Alex Pilafian - 2014/12 

#Solves the Traveling Salesman problem using the Branch and Bound technique.

#This technique gives an exact solution to the problem in O((n-1)!) time. 

require 'matrix' #also requires Vector

class Matrix
  def pretty_print
    self.to_a.each {|r| puts r.inspect}
    return nil
  end
  
  def row_reduction
    reduction_ar = Array.new
    reduced_matrix_ar = self.to_a
    (0..(self.row_size-1)).each do |i|
      row = self.row(i)
      minval = row.min
      reduction_ar.push(minval)
      reduced_matrix_ar[i] = row.to_a.collect do |row_el|
        next(Float::INFINITY) if (row_el.equal? Float::INFINITY or minval.equal? Float::INFINITY)

        row_el - minval
      end
    end

    return {
      :matrix=>Matrix[*reduced_matrix_ar], 
      :reduction=>reduction_ar.reject{|el| el.equal? Float::INFINITY}
    }
  end
  
  def column_reduction
    reduction_ar = Array.new
    reduced_matrix_ar = self.to_a
    (0..(self.column_size-1)).each do |j|
      col = self.column(j)
      minval = col.min
      reduction_ar.push(minval) 
      (0..(self.row_size-1)).each do |i|
        val = reduced_matrix_ar[i][j]

        next(Float::INFINITY) if (val.equal? Float::INFINITY or minval.equal? Float::INFINITY)

        reduced_matrix_ar[i][j] = val - minval
      end
    end

    return {
      :matrix=>Matrix[*reduced_matrix_ar], 
      :reduction=>reduction_ar.reject{|el| el.equal? Float::INFINITY}
    }
  end
  
  def reduction
    rowred_result_obj = self.row_reduction
    total_reduction = rowred_result_obj[:reduction].inject(0){|memo, x| memo += x}
    
    colred_result_obj = rowred_result_obj[:matrix].column_reduction
    total_reduction += colred_result_obj[:reduction].inject(0){|memo, x| memo += x}
    
    reduction_mtx = colred_result_obj[:matrix]
    
    {:matrix=>reduction_mtx, :total_reduction=>total_reduction}
  end
end

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

    if(not @parent.nil?)
      self.set_cost_matrix(parent.reduced_cost_matrix.clone)
      @visited_this_tour = parent.visited_this_tour.clone
      self.calculate_base_cost!
    end

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

  def create_children!
    all_cities = TSP.cities.keys
    all_cities.reject!{|city_id| self.visited_this_tour.include?(city_id)}
    all_cities.each do |city_id|
      @children << Node.new(city_id, self)
    end
  end

  def calculate_base_cost!
    result_obj = self.cost_matrix.reduction

    @base_cost = result_obj[:total_reduction]
    if(self.parent)
      @base_cost += self.parent.base_cost + self.parent.reduced_cost_matrix[self.parent.city_id, self.city_id]
    end

    @reduced_cost_matrix = result_obj[:matrix]
  end

  def <=>(another_node)
    return self.base_cost <=> another_node.base_cost
  end
end

class TSP
  @@cities = {}

  def self.cities
    @@cities
  end

  attr_accessor :root_node
  attr_accessor :adj_matrix
  
  def read_cities_from_input!
    file = nil

    if(ARGV[0] and not ARGV[0].empty?)
      file = File.open(ARGV[0], "r")
    else
      file = ARGF
    end

    file.each_with_index do |line, idx|
        line_ar = line.split("\t")
        @@cities[idx] = {:name=>line_ar[0], :location=>Vector[line_ar[1].to_f, line_ar[2].to_f]}
    end
  end
  
  def calculate_adjacency_matrix!
    @adj_matrix = Matrix.build(@@cities.length) do |i,j|
      if(i == j)
        next Float::INFINITY
      end
        
      next (@@cities[i][:location] - @@cities[j][:location]).magnitude
    end
  end
  
  def initialize
    @@cities ||= Hash.new
    if(@@cities.empty?)
      self.read_cities_from_input!
    end
  end
  
  def solve!
    #calculates the initial adjacency matrix
    self.calculate_adjacency_matrix!

    #create the root node, with city ID 0 (for Beijing)
    self.root_node = Node.new(0)
    self.root_node.set_cost_matrix(self.adj_matrix) #set the cost matrix to the adjacency matrix

    #calculate the base cost manually (usually would happen during init but ROOT lacks a parent)
    self.root_node.calculate_base_cost!
    node = self.root_node

    while(node.visited_this_tour.size < @@cities.size)
      node.create_children!

      best_node = node.children.min
      node = best_node
    end


    node.visited_this_tour.each do |city_id|
      puts @@cities[city_id][:name]
    end


  end
  
end

tsp = TSP.new
tsp.solve!