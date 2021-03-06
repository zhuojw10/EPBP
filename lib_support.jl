# LIB_SUPPORT.JL
#	definition of useful functions used in various places of the project
#
# 	Code released under the MIT license, see corresponding LICENSE file
#	(c) 2015, Thibaut Lienart
#
# --------------------------------------------------------------------------------------------------
#
using Distributions  # cf. http://distributionsjl.readthedocs.org/
#
# --------------------------------------------------------------------------------------------------
# QUICK FUNCTIONS
#
# > NORMALDIV: divide two 1D normals given M1=[mu1 s1] M2=[mu2 s2]
normal_div(M1,M2) = [ (M2[2]^2*M1[1]-M1[2]^2*M2[1])/(M2[2]^2-M1[2]^2),
						M1[2]*M2[2]/sqrt(M2[2]^2-M1[2]^2) ]
# > NORMALPROD: multiply two 1D normals
normal_prod(M1,M2) = [ (M2[2]^2*M1[1]+M1[2]^2*M2[1])/(M2[2]^2+M1[2]^2),
						 M1[2]*M2[2]/sqrt(M2[2]^2+M1[2]^2) ]
# > GET_NEIGHBORS: list of index of neighbors
get_neighbors(node) = edge_list[edge_list[:,1].==node,2]
# > GET_EDGE_IDX: returns bool vector corresponding to extraction of edge info
get_edge_idx(from,to) 	  = (edge_list[:,1].==from) .* (edge_list[:,2].==to)
get_edge_weights(from,to) = e_weights[get_edge_idx(from,to),:]
get_edge_eta(from,to)     = eta_moments[get_edge_idx(from,to),:]
get_node_eta(node) 		  = eta_node_moments[node,:]
# > GET_TIME: return the time since last time flag rounded to 3 decimals
get_time(_flag) = round(time()-_flag,3)
#
# --------------------------------------------------------------------------------------------------
#
# GM_CHAIN(T)
#	Declare a T chain (HMM)
#
function gm_chain(T)
	nnodes = T
	nedges = T-1
	#
	edge_list = int(ones(2*nedges,2))
	#
	edge_list[:,1] = [1:nedges,nedges+1:-1:2]
	edge_list[:,2] = [2:nedges+1,nedges:-1:1]
	#
	return nnodes,nedges,edge_list
end
#
# GM_CHAIN_SCHEDULING
# 	Declare a standard chain scheduling
#		> Forward (1->T)
#		> Backward (T->1)
#
function gm_chain_scheduling(T,forwardonly=false)
	if forwardonly
		return 1:T
	else
		return [1:T,T-1:-1:2]
	end
end

#
# GM_GRID(M,N):
# 	Declare an m*n regular grid
#
function gm_grid(m,n)
	nnodes = n*m
	nedges = (2*m-1)*(n-1)+m-1
	#
	edge_list = int(ones(2*nedges,2))
	edge_idx  = 1
	#
	for node = 1:nnodes
		node_i,node_j = ind2sub((m,n),node)
		node_ij       = [node_i node_j]
        neighbors 	  = repmat(node_ij,4,1) + [[0 1],[0 -1],[1 0],[-1 0]]
        # get rid of neighbors that don't exist
        valid_idx = (neighbors[:,1].>=1) .* (neighbors[:,2].>=1) .*
        			(neighbors[:,1].<=m) .* (neighbors[:,2].<=n)
        neighbors = neighbors[valid_idx,:]
        for k = 1:size(neighbors,1)
        	neigh_i,neigh_j       = neighbors[k,:]
        	edge_list[edge_idx,:] = [node sub2ind((m,n),neigh_i,neigh_j)]
        	edge_idx 			 += 1
        end
    end
	return nnodes,nedges,edge_list
end
#
# GM_GRID_SCHEDULING(M,N):
#	Declare a standard grid scheduling over M*N grid
#	> Top-Bottom-Left-Right (natural indexing order)
#	> Left-Right-Top-Bottom (transpose)
#	> Bottom-Top-Right-Left (reversed natural)
#	> Right-Left-Bottom-Top (reversed transpose)
#
function gm_grid_scheduling(m,n)
	indices    = reshape(1:m*n,m,n)
	indices_t  = indices'
	node_order = [indices[:], indices_t[:], flipud(indices[:]), flipud(indices_t[:])]
	return node_order
end
