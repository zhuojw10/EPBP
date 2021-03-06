#
# 	Code released under the MIT license, see corresponding LICENSE file
#	(c) 2015, Thibaut Lienart
#
# --------------------------------------------------------------------------------------------------
#
# additional support functions
#
get_message(from,to) = messages[get_edge_idx(from,to),:]
#
# --------------------------------------------------------
#
# PBP_NODE_UPDATE(NODE):
#   Update of a node following the PBP method where
#   the proposals are the last estimated beliefs
#   sampled using Metropolis Hastings
#
function pbp_node_update(node)
    #
    neighbors = get_neighbors(node)
    K         = length(neighbors)
    #
    # STEP 1(A): sample from proposal
    #
    node_p     = particles[node,:]  # (size 1,N)
    old_belief = b_evals[node,:]    # (size 1,N)
    #
    for iter=1:MHIter
        cand_p     = sampleMHP(node_p) # (size 1,N)
        cur_belief = pbp_eval_belief(node,cand_p)
        #
        # acceptance ratio
        #
        alpha  = cur_belief./old_belief
        accept = rand(1,N).<alpha
        #
        node_p[accept]     = cand_p[accept]
        old_belief[accept] = cur_belief[accept]
        #
    end
    old_belief       /= sum(old_belief)
    particles[node,:] = node_p
    b_evals[node,:]   = old_belief
    #
    # STEP 1(B): evaluate incoming messages at new points
    #
    for k = 1:K
        neighb   = neighbors[k]
        neighb_p = particles[neighb,:]
        mess     = zeros(1,N)
        #
        for j=1:N # incoming message
            tmp     = eval_edge_pot(neighb,node,neighb_p,node_p[j])
            tmp   .*= eval_node_pot(neighb,neighb_p)
            tmp   ./= get_message(node,neighb)
            mess[j] = sum(tmp)
        end
        mess /= sum(mess)
        # store
        messages[get_edge_idx(neighb,node),:] = mess
    end
    #
    # STEP 2: evaluate outgoing messages
    #
    for k = 1:K
        neighb   = neighbors[k]
        neighb_p = particles[neighb,:]
        mess     = zeros(1,N)
        #
        for j=1:N
            tmp     = eval_edge_pot(node,neighb,node_p,neighb_p[j])
            tmp   .*= eval_node_pot(node,node_p)
            tmp   ./= get_message(neighb,node)
            mess[j] = sum(tmp)
        end
        mess /= sum(mess)
        # store
        messages[get_edge_idx(node,neighb),:] = mess
    end
end
#
# --------------------------------------------------------
#
# PBP_NODE_UPDATE2(NODE):
#   Update of a node following the PBP method where
#   the proposals are the last estimated beliefs
#   sampled using Metropolis Hastings
#
function pbp_node_update2(node)
    #
    neighbors = get_neighbors(node)
    K         = length(neighbors)
    #
    # STEP 1(A): sample from proposal
    #
    node_p     = particles[node,:]  # (size 1,N)
    old_belief = b_evals[node,:]    # (size 1,N)
    #
    istart = rand(1:N)
    cur_p = node_p[istart]
    cur_b = old_belief[istart]
    #
    naccept = 0
    acc_p = zeros(1,LMHCHAIN)
    acc_b = zeros(1,LMHCHAIN)
    while naccept < LMHCHAIN
        cand_p = sampleMHP2(cur_p)
        cand_b = pbp_eval_belief(node,cand_p)
        # acc ratio
        alpha  = cand_b./cur_b
        alpha  = alpha[1]
        if rand()<alpha
            acc_p[naccept+1] = cand_p[1]
            acc_b[naccept+1] = cand_b[1]
            cur_p = cand_p
            cur_b = cand_b
            naccept += 1
        end
    end
    acc_p = acc_p[LMHCHAIN:-1:LMHCHAIN-ENDCHUNK+1]
    acc_b = acc_b[LMHCHAIN:-1:LMHCHAIN-ENDCHUNK+1]
    idx   = rand(1:ENDCHUNK,N)
    node_p = acc_p[idx]
    bel_p  = acc_b[idx]
    bel_p  /= sum(bel_p)
    #
    particles[node,:] = node_p
    b_evals[node,:]   = bel_p
    #
    # STEP 1(B): evaluate incoming messages at new points
    #
    for k = 1:K
        neighb   = neighbors[k]
        neighb_p = particles[neighb,:]
        mess     = zeros(1,N)
        #
        for j=1:N # incoming message
            tmp     = eval_edge_pot(neighb,node,neighb_p,node_p[j])
            tmp   .*= eval_node_pot(neighb,neighb_p)
            tmp   ./= get_message(node,neighb)
            mess[j] = sum(tmp)
        end
        mess /= sum(mess)
        # store
        messages[get_edge_idx(neighb,node),:] = mess
    end
    #
    # STEP 2: evaluate outgoing messages
    #
    for k = 1:K
        neighb   = neighbors[k]
        neighb_p = particles[neighb,:]
        mess     = zeros(1,N)
        #
        for j=1:N
            tmp     = eval_edge_pot(node,neighb,node_p,neighb_p[j])
            tmp   .*= eval_node_pot(node,node_p)
            tmp   ./= get_message(neighb,node)
            mess[j] = sum(tmp)
        end
        mess /= sum(mess)
        # store
        messages[get_edge_idx(node,neighb),:] = mess
    end
end

#
# --------------------------------------------------------
#
# PBP_EVAL_BELIEF(NODE,EVAL_POINTS):
#   Evaluate the current estimator of the beliefs at
#   a given node and for given points.
#   For that, all the incoming messages are evaluated
#   and the product is taken.
#
function pbp_eval_belief(node,eval_points)
    #
    neighbors = get_neighbors(node)
    K,M       = length(neighbors),length(eval_points)
    #
    cur_belief = eval_node_pot(node,eval_points) # (size 1,M)
    #
    for k = 1:K
        neighb   = neighbors[k]
        neighb_p = particles[neighb,:]
        mess     = zeros(1,M) # incoming message (size 1,M)
        for j=1:M
            tmp     = eval_edge_pot(neighb,node,neighb_p,eval_points[j])
            tmp   .*= eval_node_pot(neighb,neighb_p)
            tmp   ./= get_message(node,neighb)
            mess[j] = sum(tmp)
        end
        mess        /= sum(mess)
        cur_belief .*= mess
    end
    cur_belief /= sum(cur_belief)
    return cur_belief
end
