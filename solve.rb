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
      reduction_ar.push(row.min) 
      reduced_matrix_ar[i] = row.to_a.collect{|row_el| row_el - row.min}
    end

    return {
      :matrix=>Matrix[*reduced_matrix_ar], 
      :reduction=>reduction_ar
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
        reduced_matrix_ar[i][j] = val - minval
      end
    end

    return {
      :matrix=>Matrix[*reduced_matrix_ar], 
      :reduction=>reduction_ar
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
  attr_accessor :parent #Node[]
  attr_accessor :city_id #integer
  
  attr_accessor :base_cost #Float
  attr_accessor :cost_matrix #Matrix
  attr_accessor :reduced_cost_matrix #Matrix
  
  attr_accessor :blocked #Integer[]
  
    def initialize city_id, parent=nil
      @city_id = city_id
      @parent = parent
      
      if(not @parent.nil?)
        #clone some data from the parent for this node...
        @cost_matrix = parent.reduced_cost_matrix.clone
        @blocked = parent.blocked.clone
      end
      
      self.calculate_base_cost!
    end
    
    def calculate_base_cost!
    end
 
    def <=>(another_node)
      return self.base_cost <=> another_node.base_cost
    end
end

class TSP
  
  attr_accessor :cities
  attr_accessor :adj_matrix
  
  def read_cities_from_stdin!
    file = nil

    if(ARGV[0] and not ARGV[0].empty?)
      file = File.open(ARGV[0], "r")
    else
      file = ARGF
    end

    file.each_with_index do |line, idx|
        line_ar = line.split("\t")
        @cities[idx] = {:name=>line_ar[0], :location=>Vector[line_ar[1].to_f, line_ar[2].to_f]}
    end
  end
  
  def calculate_adjacency_matrix!
    @adj_matrix = Matrix.build(@cities.length) do |i,j|
      if(i == j)
        next Float::INFINITY
      end
        
      next (@cities[i][:location] - @cities[j][:location]).magnitude
    end
  end
  
  def initialize
    @cities ||= Hash.new
    if(@cities.empty?)
      self.read_cities_from_stdin!
    end
    
    self.calculate_adjacency_matrix!
  end
  
  def solve!

  end
  
end

tsp = TSP.new
tsp.solve!