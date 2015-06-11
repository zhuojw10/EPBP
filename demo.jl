#
# Accomodates: 1D, Normal approx (2 moments)
# > should be flexible wrt these params in future
#
# things that should be determined by the user in this code
# > everything related to declaration of graphical model
# > how to initialize the proposals
# >> check [!USER!]
#
include("lib_support.jl")
include("lib_epbp.jl")
include("lib_lbpd.jl")
include("lib_pbp.jl")
#
RELOAD = false
LBPD   = false
EPBP   = false
FEPBP  = false
PBP    = true
#
expname = "demoIsing"
if ~isdir(expname)
    mkdir(expname)
end
#
# SIMULATION PARAMETERS
#
Nlist	= [100]		# number of particles per node [!USER!]
Clist 	= [10]		# number of components for FEPBP [!USER!]
Ninteg  = 30		# number of integration points for EP proj
Ngrid   = 200		# number of points in the discretization
nloops  = 10 		# number of loops through scheduling [!USER!]
nruns   = 1  		# number of time we run the whole thing [!USER!]
#
MHIter 	   = 20
MHProposal = Normal(0,.1)
#
# DECLARE GRAPHICAL MODEL
#
# > declare underlying structure (cf. EPBP_SUPPORT_LIB) # [!USER!]
m,n = 5,5
nnodes,nedges,edge_list = gm_grid(m,n)
# > declare scheduling [!USER!]
scheduling = gm_grid_scheduling(m,n)
# > declare edge and node potential [!USER!]
node_potential = MixtureModel([Normal(-2,1),Gumbel(2,1.3)],[0.6,0.4])
edge_potential = Laplace(0,2)
# > estimated range + testing points [!USER!]
est_range = (-5,15)
integ_pts = linspace(est_range[1],est_range[2],Ninteg)' # ! leave the transpose
grid      = linspace(est_range[1],est_range[2],Ngrid)'
# 
HOMOG_EDGE_POT = true # if edge pot is the same everywhere
#
eval_edge_pot(from,to,xfrom,xto) = pdf(edge_potential,xfrom-xto)
eval_node_pot(node,xnode)        = pdf(node_potential,obs_values[node]-xnode)
#	
# > initial values [!USER!]
orig_values = zeros(nnodes,1) + 2
# > generate observations
if RELOAD
	# > generate observations
	obs_values = orig_values + rand(node_potential,nnodes)
	writecsv("$expname/$expname\_orig_values.dat",orig_values)
	writecsv("$expname/$expname\_obs_values.dat",obs_values)
	#
	obs_var = sqrt(var(obs_values))
	s_init  = 4*obs_var
end

if LBPD
	_start_lbpd = time()
    println("LBPD sim ($expname::$Ngrid)")
	# > pre-allocation of storage space
	global messages = ones(2*nedges,Ngrid)
	global beliefs  = zeros(nnodes,Ngrid)
	# > initial beliefs: just node pot (mess=1)
	for node=1:nnodes
		neighbors   	= get_neighbors(node)
		cur_beliefs 	= eval_node_pot(node,grid)
		beliefs[node,:] = cur_beliefs/sum(cur_beliefs)
	end
	# > pre-computation in case of homogeneous edge pot
	global	edge_pot_grid = []
	if HOMOG_EDGE_POT
		edge_pot_grid = zeros(Ngrid,Ngrid)
		for gi=1:Ngrid
			for gj=1:Ngrid
				edge_pot_grid[gi,gj]=eval_edge_pot(0,0,grid[gi],grid[gj])
			end
		end
	end
	# > keep init belief, useful for later comp
	init_beliefs = copy(beliefs)
	#
	for loop = 1:nloops
		print(">loop: ",loop)
		_start_loop = time()
		for i=1:length(scheduling)
			lbpd_node_update(scheduling[i])
		end
		println(" [completed in ",get_time(_start_loop),"s]")
	end
	println("LBPD completed in ",get_time(_start_lbpd),"s.")
	#
	writecsv("$expname/$expname\_lbpd_origbel_np$Ngrid.dat",init_beliefs)
    writecsv("$expname/$expname\_lbpd_grid_np$Ngrid.dat",	grid)
    writecsv("$expname/$expname\_lbpd_beliefs_np$Ngrid.dat",beliefs)
end

for N_index in 1:length(Nlist)
	global N = Nlist[N_index]
	global C = Clist[N_index] # for FEPBP
	#
	for run = 1:nruns
		if EPBP 
			_start_epbp = time()
            println("EPBP sim ($expname::$N) [run::$run]")
			# > pre-allocation of storage space
			global particles   = zeros(nnodes,N)
			global b_weights   = zeros(nnodes,N)
			global b_evals     = zeros(nnodes,N)
			global q_moments   = zeros(nnodes,2)
			global e_weights   = zeros(2*nedges,N)
			global eta_moments = zeros(2*nedges,2)
			#
			# > initial proposals & particles [!USER!]
			for node = 1:nnodes
				mu_node   		  = obs_values[node]
				q_moments[node,:] = [ mu_node s_init ]
				particles[node,:] = mu_node + s_init*randn(N,1)
			end
			#
			# > initial edge weights
			for edge = 1:2*nedges
				from     = edge_list[edge,1]
				weights  = eval_node_pot(from,particles[from,:])
				weights /= sum(weights)
				#
				e_weights[edge,:] = weights
			end
			#
			orig_q_moments   = copy(q_moments)
			orig_eta_moments = copy(eta_moments)
			#
			for loop = 1:nloops
				print(">loop: ",loop)
				_start_loop = time()
				for i=1:length(scheduling)
					epbp_node_update(scheduling[i])
				end
				println(" [completed in ",get_time(_start_loop),"s]")
			end
			println("EPBP completed in ",get_time(_start_epbp),"s.")
			print("...eval est. beliefs on mesh...")
			_start_epbp_estbel = time()
			epbp_est_beliefs   = zeros(nnodes,Ngrid)
			for node = 1:nnodes
				t1,t2  = epbp_eval_belief(node,grid)
				epbp_est_beliefs[node,:] = t2
			end
			println(" [done in ",get_time(_start_epbp_estbel),"s]")
			#
	        writecsv("$expname/$expname\_epbp_est_beliefs_np$N\_run$run.dat",epbp_est_beliefs)
	        writecsv("$expname/$expname\_epbp_particles_np$N\_run$run.dat",	particles)
	        writecsv("$expname/$expname\_epbp_weights_np$N\_run$run.dat",	b_weights)
	        writecsv("$expname/$expname\_epbp_evals_np$N\_run$run.dat",		b_evals)
	        writecsv("$expname/$expname\_epbp_qmom_np$N\_run$run.dat",		q_moments)
		end
		#
		# -----------------------------------------------------------------------------------------
		#
		if FEPBP 
			_start_fepbp = time()
            println("FEPBP sim ($expname::$N/$C) [run::$run]")
			# > pre-allocation of storage space
			global particles   = zeros(nnodes,N)
			global b_weights   = zeros(nnodes,N)
			global b_evals     = zeros(nnodes,N)
			global q_moments   = zeros(nnodes,2)
			global e_weights   = zeros(2*nedges,N)
			global eta_moments = zeros(2*nedges,2)
			#
			# > initial proposals & particles [!USER!]
			for node = 1:nnodes
				mu_node   		  = obs_values[node]
				q_moments[node,:] = [ mu_node s_init ]
				particles[node,:] = mu_node + s_init*randn(N,1)
			end
			#
			# > initial edge weights
			for edge = 1:2*nedges
				from     = edge_list[edge,1]
				weights  = eval_node_pot(from,particles[from,:])
				weights /= sum(weights)
				#
				e_weights[edge,:] = weights
			end
			#
			orig_q_moments   = copy(q_moments)
			orig_eta_moments = copy(eta_moments)
			#
			for loop = 1:nloops
				print(">loop: ",loop)
				_start_loop = time()
				for i=1:length(scheduling)
					epbp_node_update(scheduling[i],true) # with fastmode
				end
				println(" [completed in ",get_time(_start_loop),"s]")
			end
			println("FEPBP completed in ",get_time(_start_fepbp),"s.")
			print("...eval est. beliefs on mesh...")
			_start_fepbp_estbel = time()
			fepbp_est_beliefs   = zeros(nnodes,Ngrid)
			for node = 1:nnodes
				t1,t2  = epbp_eval_belief(node,grid) # complete eval (not fast)
				fepbp_est_beliefs[node,:] = t2
			end
			println(" [done in ",get_time(_start_fepbp_estbel),"s]")
			#
	        writecsv("$expname/$expname\_fepbp_est_beliefs_np$N\_nc$C\_run$run.dat",fepbp_est_beliefs)
	        writecsv("$expname/$expname\_fepbp_particles_np$N\_nc$C\_run$run.dat",  particles)
	        writecsv("$expname/$expname\_fepbp_weights_np$N\_nc$C\_run$run.dat",	b_weights)
	        writecsv("$expname/$expname\_fepbp_evals_np$N\_nc$C\_run$run.dat",      b_evals)
	        writecsv("$expname/$expname\_fepbp_qmom_np$N\_nc$C\_run$run.dat",		q_moments)
		end
		if PBP
			_start_pbp = time()
            println("PBP sim ($expname::$N) [run::$run]")
            # 
            sampleMHP(old) = old[:]+rand(MHProposal,N)
            # 
			# > pre-allocation of storage space
			global particles   = zeros(nnodes,N)
			global b_evals     = zeros(nnodes,N)
			global messages    = zeros(2*nedges,N)
			#
			for node=1:nnodes
				node_p = obs_values[node]+sinit*randn(1,N)
				bel_p  = eval_node_pot(node,node_p)
				particles[node,:] = node_p
				b_evals[node,:]   = bel_p/sum(bel_p)
			end
			#
			for loop=1:nloops
				print(">loop: ",loop)
				_start_loop = time()
				for i=1:length(scheduling)
					pbp_node_update(scheduling[i]) # with fastmode
				end
				println(" [completed in ",get_time(_start_loop),"s]")
			end
			#
			println("PBP completed in ",get_time(_start_pbp),"s.")
			print("...eval est. beliefs on mesh...")
			_start_pbp_estbel = time()
			pbp_est_beliefs   = zeros(nnodes,Ngrid)
			for node = 1:nnodes
				t1,t2  = pbp_eval_belief(node,grid)
				pbp_est_beliefs[node,:] = t2
			end
			println(" [done in ",get_time(_start_pbp_estbel),"s]")
			#
	        writecsv("$expname/$expname\_pbp_est_beliefs_np$N\_run$run.dat",pbp_est_beliefs)
	        writecsv("$expname/$expname\_pbp_particles_np$N\_run$run.dat",  particles)
	        writecsv("$expname/$expname\_pbp_evals_np$N\_run$run.dat",      b_evals)
		end
	end
end