### A Pluto.jl notebook ###
# v0.19.46

using Markdown
using InteractiveUtils

# ╔═╡ ff03fed8-50f9-4b13-95ee-5ff0c596f87e
begin
  using Pkg, DrWatson
  using PlutoUI
  TableOfContents()
end

# ╔═╡ d577b8c8-3670-497a-a6fe-41208a8e8501
begin
	using Turing
	using Turing
	using DataFrames
	using CSV
	using Random
	using Dagitty
	using Distributions
	using StatisticalRethinking
	using StatisticalRethinking: link
	using StatisticalRethinkingPlots
	using StatsPlots
	using StatsBase
	using Logging
	using LinearAlgebra
end

# ╔═╡ b7be9915-1237-4aa1-b7e5-493b704ccb79
md"# Chap 14: Adventures in Covariance"

# ╔═╡ 717da12e-ac23-4585-9661-e9f4fd7447fd
versioninfo()

# ╔═╡ 95965ab2-f250-479f-9d5d-e478dba1fe35
html"""
<style>
	main {
		margin: 0 auto;
		max-width: max(1800px, 75%);
    	padding-left: max(5px, 1%);
    	padding-right: max(350px, 10%);
	}
</style>
"""

# ╔═╡ 90028541-7308-476f-b51b-850cd6ad39c4
begin
	Plots.default(label=false);
	#Logging.disable_logging(Logging.Warn)
end;

# ╔═╡ 1217e4ab-8e97-4b73-9493-a58c7d8165fe
md" # 14.1 Varying slopes by construction."

# ╔═╡ 100c3470-b7e4-4890-9347-851b78f5202f
md" #### Code 14.1 - 14.4"

# ╔═╡ 464ddfd5-d06b-4615-bd23-e63e03a29f1e
md"

!!! note

Julia has similar `column-first` matix order."

# ╔═╡ fe81bd6a-c7bf-437d-8ca6-f21f9b45b41f
reshape(1:4, (2,2))

# ╔═╡ b6c8f7af-8e39-4792-a62c-88a41876345d
md" ## Code 14.5 - 14.8 Simulate `a_cafe` (intercept) and `b_cafe`(slope)"

# ╔═╡ 8ee2eec3-3214-48d1-8604-a54ba1a67baf
let
	a = 3.5    # average morning wait time
	b = -1     # average difference afternoon wait time
	σ_a = 1    # std dev in intercepts
	σ_b = 0.5  # std dev in slopes
	ρ = -0.7;  # correlation between intercepts and slopes
	
	global μ = [a, b]
	cov_ab = σ_a * σ_b * ρ
	global Σ₂ = [[σ_a^2, cov_ab] [cov_ab, σ_b^2]]
	sigmas = [σ_a, σ_b]
	Ρ = [[1, ρ] [ρ, 1]]
	
	global Σ₃ = Diagonal(sigmas) * Ρ * Diagonal(sigmas)
	N_cafes = 20
	Random.seed!(5)
	vary_effect = rand(MvNormal(μ, Σ₃), N_cafes)
	global a_cafe = vary_effect[1,:]
	global b_cafe = vary_effect[2,:];
end

# ╔═╡ aab03d9d-7ae3-4d80-9e25-75e047dbdce1
Σ₂

# ╔═╡ be9eae13-c04e-492f-9b74-a68b769c7628
Σ₃

# ╔═╡ c64bc09c-0c4b-429d-a91c-fc9915d0dbfa
a_cafe

# ╔═╡ c79ba67c-0694-445f-b320-30cdb88190be


# ╔═╡ 573253a5-10d4-458e-9451-89c763658810
md" ## Code 14.9 Plot `a_cafe`(intercepts) vs `b_cafe`(slopes) and its contour"

# ╔═╡ fa9dff6f-3182-4093-bbfd-8deea404eab0
let
	p = scatter(a_cafe, b_cafe, xlab="intercepts (a_cafe)", ylab="slopes (b_cafe)")
	
	d = acos(Σ₂[1,2])
	chi = Chisq(2)
	
	for l ∈ (0.1, 0.3, 0.5, 0.8, 0.99)
	    scale = sqrt(quantile(chi, l))
	    xₜ(t) = scale*Σ₂[1,1]*cos(t + d/2) + μ[1]
	    yₜ(t) = scale*Σ₂[2,2]*cos(t - d/2) + μ[2]
	
	    plot!(xₜ, yₜ, 0, 2π, c=:black, alpha=0.3)
	end
	p
end

# ╔═╡ 2367f3cf-c568-4f6c-82c6-b7ae42408404
md" ## Code 14.10 Simulate observations"

# ╔═╡ 8185285a-1640-45e9-8c80-b17b6c960804
let
	Random.seed!(1)
	N_cafes = 20
	N_visits = 10
	
	afternoon = repeat(0:1, N_visits*N_cafes ÷ 2)
	cafe_id = repeat(1:N_cafes, inner=N_visits)
	μ = a_cafe[cafe_id] + b_cafe[cafe_id] .* afternoon
	σ = 0.5
	wait = rand.(Normal.(μ, σ))
	global cafes = DataFrame(cafe=cafe_id, afternoon=afternoon, wait=wait);
end

# ╔═╡ 40634f53-8104-4791-877c-2d498cab9570
md" ## Code 14.11 LKJ prior on ρ "

# ╔═╡ 885a0261-3541-4389-beb7-231c77e2dfcc
let
	R = rand(LKJ(2, 2), 10^4);
	density(getindex.(R, 2), xlab="Correlation")
end

# ╔═╡ 6837fff8-0c29-4ba1-9b3b-b21c23d861eb
md" ## Code 14.12 `m14_1` multilevel covariance model"

# ╔═╡ 30be727e-86e6-41cf-be58-e0b1ffb372c2
md" ## Code 14.13 Posterior vs prior of ρ"

# ╔═╡ f95ec79a-0263-46e4-b82e-a274cb7ee7fb
md" ## Code 14.14 Draw posterior estimates of intercept vs slope"

# ╔═╡ 81f57cdb-36f8-43bb-86a5-19bac5cd88b1
md"

!!! note

Plot differs from presented in the book due to different seed in data generation."

# ╔═╡ 4ea3a429-e457-48a1-a66a-ea66ff21d22c
md" ## Code 14.15 Draw the contour of posterior estimates"

# ╔═╡ 5188efaa-8a5e-4fac-9e7f-bf048079ab9c
md" ## Code 14.16 Draw morning wait vs afternoon wait"

# ╔═╡ 91780708-0829-4beb-8144-7fc5b7e76b3f
md" ## Code 14.17 Draw contour , but failed."

# ╔═╡ e049f64c-02e0-4087-b341-eaf437c5ba49
md"# 14.2 Advanced varying slopes."

# ╔═╡ 687aec56-682c-4153-ac35-58926c03ea26
md" ## Code 14.18 Load data and fit model m14_2"

# ╔═╡ 0c918f86-e896-4b19-8cf8-a77203c3a61b
begin
	chimpanzees = CSV.read(sr_datadir("chimpanzees.csv"), DataFrame)
	chimpanzees.treatment = 1 .+ chimpanzees.prosoc_left .+ 2*chimpanzees.condition;
	chimpanzees.block_id = chimpanzees.block;
end;

# ╔═╡ fee0f70c-9aa5-4b60-a285-6923fedbd06c
@model function m14_2(L, tid, actor, block_id)
    tid_len = length(levels(tid))
    act_len = length(levels(actor))
    blk_len = length(levels(block_id))
    g ~ filldist(Normal(), tid_len)

    σ_actor ~ filldist(Exponential(), tid_len)
    ρ_actor ~ LKJ(tid_len, 2)
    Σ_actor = (σ_actor .* σ_actor') .* ρ_actor
    alpha ~ filldist(MvNormal(zeros(tid_len), Σ_actor), act_len)

    σ_block ~ filldist(Exponential(), tid_len)
    ρ_block ~ LKJ(tid_len, 2)
    Σ_block = (σ_block .* σ_block') .* ρ_block
    beta ~ filldist(MvNormal(zeros(tid_len), Σ_block), blk_len)
    
    for i ∈ eachindex(L)
        p = logistic(g[tid[i]] + alpha[tid[i], actor[i]] + beta[tid[i], block_id[i]])
        L[i] ~ Bernoulli(p)
    end
end

# ╔═╡ 57050894-2fcb-48e0-bd41-14502da1b5ae
begin
	Random.seed!(123)
	@time m14_2_ch = sample(m14_2(chimpanzees.pulled_left, chimpanzees.treatment, chimpanzees.actor, chimpanzees.block_id),
		Turing.HMC(0.01, 10), 1000);
	m14_2_df = DataFrame(m14_2_ch);
end

# ╔═╡ d31c38f1-94b9-468c-9bce-0469d933c48f
describe(m14_2_df[:, r"σ"])

# ╔═╡ aab44993-2275-40dd-8d91-2efb1008ce77
std.(eachcol(m14_2_df[:, r"σ"]))

# ╔═╡ 2a1dd0cf-5a09-43bd-b7bf-5c93bea3bf3b
md" ## Code 14.19 `m14_3` non-centered approach via Cholesky Decomposition"

# ╔═╡ d15e5041-6021-483e-b059-7170077c2ea6
@model function m14_3(L, tid, actor, block_id)
    tid_len = length(levels(tid))
    act_len = length(levels(actor))
    blk_len = length(levels(block_id))
    g ~ filldist(Normal(), tid_len)

    σ_actor ~ filldist(Exponential(), tid_len)
    # LKJCholesky is not usable in Turing: https://github.com/TuringLang/Turing.jl/issues/1629
    ρ_actor ~ LKJ(tid_len, 2)    
    ρ_actor_L = cholesky(Symmetric(ρ_actor)).L
    z_actor ~ filldist(MvNormal(zeros(tid_len), 1), act_len)
    alpha = (σ_actor .* ρ_actor_L) * z_actor

    σ_block ~ filldist(Exponential(), tid_len)
    ρ_block ~ LKJ(tid_len, 2)
    ρ_block_L = cholesky(Symmetric(ρ_block)).L        
    z_block ~ filldist(MvNormal(zeros(tid_len), 1), blk_len)
    beta = (σ_block .* ρ_block_L) * z_block

    for i ∈ eachindex(L)
        p = logistic(g[tid[i]] + alpha[tid[i], actor[i]] + beta[tid[i], block_id[i]])
        L[i] ~ Bernoulli(p)
    end
end

# ╔═╡ 425eea72-221d-4990-90f2-a6654f4e98e1
md"

!!! note

Hm, this is less stable and slower than m14_2...
So if you know how to improve it - PR or open the issue in the repo"

# ╔═╡ ccc7d18c-08ed-41a7-a556-26030a19d6c5
begin
	Random.seed!(123)
	@time m14_3_ch = sample(m14_3(chimpanzees.pulled_left, chimpanzees.treatment, chimpanzees.actor, chimpanzees.block_id), 
    	Turing.HMC(0.01, 10), 1000)
	CHNS(m14_2_ch)
end

# ╔═╡ 6b73a8a5-c542-4a10-8cf1-0a7e40c3cc98
md" ## Code 14.20 Fig 14.6 Compare ess of `m14_2` vs `m14_3`
- not much improvement, unlike the figure in the book."

# ╔═╡ bc41a9ab-c960-4d17-9782-f01721337aea
let
	t = DataFrame(ess_rhat(m14_2_ch));
	ess_2 = t.ess[occursin.(r"σ|ρ", string.(t.parameters))]
	ess_2 = filter(v -> !isnan(v), ess_2);
	t = DataFrame(ess_rhat(m14_3_ch));
	ess_3 = t.ess[occursin.(r"σ|ρ", string.(t.parameters))]
	ess_3 = filter(v -> !isnan(v), ess_3);
	
	bounds = extrema([ess_2; ess_3]) .+ (-20, 20)
	# xaxis=:log10, yaxis=:log10, 
	scatter(ess_2, ess_3, xlim=bounds, ylim=bounds,xlab="centered (default, m14_2)", ylab="non-centered (cholesky, m14_3)")
	plot!(identity)
end

# ╔═╡ 40ec9daa-913e-4b2c-a0aa-3e70a2de7c71
md" ## Code 14.21 range of $$\sigma$$ for each actor by `m14_3`"

# ╔═╡ b938e63c-29b1-4e49-90af-f9b2ab2e5bdd
begin
	m14_3_df = DataFrame(m14_3_ch)
	describe(m14_3_df[:, r"σ"])
end

# ╔═╡ 7e316c72-496e-4758-bb78-f22cefa9fb6c
std.(eachcol(m14_3_df[:, r"σ"]))

# ╔═╡ e5428608-cfc2-4fb0-873d-9a4944fb27f6
md" ## Code 14.22 Posterior predictions (black) vs raw data (blue)"

# ╔═╡ 0d6baf1d-2e2a-4742-944a-072bbd24b628
md"

!!! note

The results for both models 2 and 3 are weird and mismatch with the book. So, something is wrong here.
Put below both link functions for experimentations.

Plot is from model 2, because model 3 is totally off."

# ╔═╡ ef730308-7bf8-489a-9ab5-a869efe6083a
let
	gd = groupby(chimpanzees, [:actor, :treatment])
	c = combine(gd, :pulled_left => mean => :val)
	global pl = unstack(c, :actor, :treatment, :val);
end

# ╔═╡ 1c4b4cb8-12c0-4fb3-8523-062c7028f746
l_fun = (r, (ai, ti)) -> begin
    bi = 5
    g = get(r, "g[$ti]", missing)
    
    σ_actor = get(r, "σ_actor[$ti]", missing)
    ρ_actor = reshape(collect(r[r"ρ_actor"]), (4, 4))
    ρ_actor_L = cholesky(Symmetric(ρ_actor)).L
    z_actor = reshape(collect(r[r"z_actor"]), (4, 7))
    alpha = (σ_actor .* ρ_actor_L) * z_actor
    a = alpha[ti, ai]
    
    σ_block = get(r, "σ_block[$ti]", missing)
    ρ_block = reshape(collect(r[r"ρ_block"]), (4, 4))
    ρ_block_L = cholesky(Symmetric(ρ_block)).L
    z_block = reshape(collect(r[r"z_block"]), (4, 6))
    beta = (σ_block .* ρ_block_L) * z_block
    b = beta[ti, bi]
    
    logistic(g + a + b)
end

# ╔═╡ 9610477f-8311-4cbf-8544-b9f4836926d6
#p_post = link(m14_3_df, l_fun, Iterators.product(1:7, 1:4))

l_fun2 = (r, (ai, ti)) -> begin
    bi = 5
    g = get(r, "g[$ti]", missing)
    a = get(r, "alpha[$ti,$ai]", missing)
    b = get(r, "beta[$ti,$bi]", missing)
    logistic(g + a + b)
end

# ╔═╡ e5216885-c156-4454-ac96-eed454435695
p_post = link(m14_2_df, l_fun2, Iterators.product(1:7, 1:4))

# ╔═╡ 6e47526a-310a-4a3e-aab5-0fe71c6c7814
let
	p_μ = map(mean, p_post)
	p_ci = map(PI, p_post);
	rel_ci = map(idx -> (p_μ[idx]-p_ci[idx][1], p_ci[idx][2]-p_μ[idx]), CartesianIndices(p_ci));
	
	n_names = ["R/N", "L/N", "R/P", "L/P"]
	p = plot(ylims=(0, 1.1), ylab="proportion left lever", showaxis=:y, xticks=false)
	hline!([0.5], c=:gray, s=:dash)
	
	# raw data
	for actor in 1:7
	    ofs = (actor-1)*4
	    actor > 1 && vline!([ofs+0.5], c=:gray)
	    plot!([ofs+1,ofs+3], collect(pl[actor,["1","3"]]), lw=2, m=:o, c=:black)
	    plot!([ofs+2,ofs+4], collect(pl[actor,["2","4"]]), lw=2, m=:o, c=:black)
	    anns = [
	        (ofs+idx, pl[actor,string(idx)]+.04, (name, 8))
	        for (idx,name) ∈ enumerate(n_names)
	    ]
	    actor != 2 && annotate!(anns)
	end
	
	annotate!([
	    (2.5 + (idx-1)*4, 1.1, ("actor $idx", 8))
	    for idx ∈ 1:7
	])
	
	# posterior predictions
	for actor in 1:7
	    ofs = (actor-1)*4
	    actor > 1 && vline!([ofs+0.5], c=:gray)
	    err = [rel_ci[actor,1], rel_ci[actor,3]]
	    plot!([ofs+1,ofs+3], collect(p_μ[actor,[1,3]]), err=err, lw=2, m=:o, c=:blue)
	    err = [rel_ci[actor,2], rel_ci[actor,4]]    
	    plot!([ofs+2,ofs+4], collect(p_μ[actor,[2,4]]), err=err, lw=2, m=:o, c=:blue)
	end
	
	p
end

# ╔═╡ 944c59b8-ecf6-4ec3-9e81-7ffb8692db36
md" # 14.3 Instruments and causal designs."

# ╔═╡ 233cd90e-463d-49fb-9a54-34e2750c2a8c
md" ## Code 14.23 Simulate: Education has no effect on Wage and U(Unknown) has positive effect on W."

# ╔═╡ b28587b9-5e60-42b0-9874-d47b3e03b97c
let
	Random.seed!(73)
	N = 500
	U_sim = rand(Normal(), N)
	Q_sim = rand(1:4, N)
	E_sim = [rand(Normal(μ)) for μ ∈ U_sim .+ Q_sim]
	W_sim = [rand(Normal(μ)) for μ ∈ U_sim .+ 0*E_sim]
	
	global dat_sim1 = DataFrame(
	    W=standardize(ZScoreTransform, W_sim),
	    E=standardize(ZScoreTransform, E_sim),
	    Q=standardize(ZScoreTransform, float.(Q_sim)),
	)
end

# ╔═╡ 4fb1f19d-2802-4a0f-bb35-1e21c0be68f3
md" ## Code 14.24 `m14_4` shows Education has strong effect on Wage!"

# ╔═╡ aad09fb4-1fee-454f-bdad-65b2a93255ca
@model function m14_4(W, E)
    σ ~ Exponential()
    aW ~ Normal(0, 0.2)
    bEW ~ Normal(0, 0.5)
    μ = @. aW + bEW * E
    W ~ MvNormal(μ, σ)
end

# ╔═╡ 0d451930-833e-4050-b2f9-d5f997fb0098
begin
	m14_4_ch = sample(m14_4(dat_sim1.W, dat_sim1.E),
	    NUTS(), 1000)
	m14_4_df = DataFrame(m14_4_ch)
	describe(m14_4_df)
end

# ╔═╡ 3878adef-0d96-4e73-ab37-4e761e01e0ac
md" ## Code 14.25 `m14_5`: Including Q amplifies the false effect of E on W."

# ╔═╡ 500fb09f-f952-46a0-8d63-98279e630882
@model function m14_5(W, E, Q)
    σ ~ Exponential()
    aW ~ Normal(0, 0.2)
    bEW ~ Normal(0, 0.5)
    bQW ~ Normal(0, 0.5)
    μ = @. aW + bEW * E + bQW * Q
    W ~ MvNormal(μ, σ)
end

# ╔═╡ 95d072b9-5940-49ce-97a8-8dde13c25939
begin
	@time m14_5_ch = sample(m14_5(dat_sim1.W, dat_sim1.E, dat_sim1.Q),
	    NUTS(), 1000)
	m14_5_df = DataFrame(m14_5_ch)
	describe(m14_5_df)
end

# ╔═╡ 1f3d5631-8261-4c3b-8e34-761d23eb5e2e
md" ## Code 14.26 Generative model to statistical model. `m14_6`: Model residual covariance between W and E.
- The effect of E on W is almost nil/zero."

# ╔═╡ a856d989-5fb6-4148-ac7d-2ce52952c1a3
@model function m14_6(W, E, Q, WE)
    σ ~ filldist(Exponential(), 2)
    ρ ~ LKJ(2, 2)
    aW ~ Normal(0, 0.2)
    aE ~ Normal(0, 0.2)
    bEW ~ Normal(0, 0.5)
    bQE ~ Normal(0, 0.5)
    μW = @. aW + bEW*E
    μE = @. aW + bQE*Q
    Σ = (σ .* σ') .* ρ
    for i ∈ eachindex(WE)
        WE[i] ~ MvNormal([μW[i], μE[i]], Σ)
    end
end

# ╔═╡ 9a7ebb96-5ce1-4093-8c85-9522edebab0e
begin
	Random.seed!(1)
	# need to combine W and E here (Turing vars limitation)
	WE = [[w,e] for (w,e) ∈ zip(dat_sim1.W, dat_sim1.E)]
	m14_6_ch = sample(m14_6(dat_sim1.W, dat_sim1.E, dat_sim1.Q, WE), 
		NUTS(200, 0.65, init_ϵ=0.003), 1000)
	m14_6_df = DataFrame(m14_6_ch);
end

# ╔═╡ 48d158ed-a25f-4ebe-8863-6c92071c251c
let
	# Drop cols with zero variance
	df = m14_6_df[:, Not("ρ[1,1]")][:, Not("ρ[2,2]")]
	describe(df)
end

# ╔═╡ 199ae6d5-7306-4802-bd18-4232fdb98f5f
md" ## Code 14.28 Simulate2: E has a positive effect on W."

# ╔═╡ aee19854-5c3d-4a9e-8639-91843800d1b6
let
	Random.seed!(73)
	
	N = 500
	U_sim = rand(Normal(), N)
	Q_sim = rand(1:4, N)
	E_sim = [rand(Normal(μ)) for μ ∈ U_sim .+ Q_sim]
	W_sim = [rand(Normal(μ)) for μ ∈ -U_sim .+ 0.2*E_sim]
	
	global dat_sim2 = DataFrame(
	    W=standardize(ZScoreTransform, W_sim),
	    E=standardize(ZScoreTransform, E_sim),
	    Q=standardize(ZScoreTransform, float.(Q_sim)),
	);
end

# ╔═╡ 762055f6-c26a-4b7b-b45b-83cacff6c779
begin
	Random.seed!(1)
	# need to combine W and E here (Turing vars limitation)
	WE_sim2 = [[w,e] for (w,e) ∈ zip(dat_sim2.W, dat_sim2.E)]
	@time m14_6_sim2_ch = sample(m14_6(dat_sim2.W, dat_sim2.E, dat_sim2.Q, WE_sim2), 
		NUTS(200, 0.65, init_ϵ=0.003), 1000)
	m14_6_sim2_df = DataFrame(m14_6_sim2_ch);
end

# ╔═╡ dba906be-9d58-471f-bbd7-4318b580ed37
let
	# Drop cols with zero variance
	df = m14_6_sim2_df[:, Not("ρ[1,1]")][:, Not("ρ[2,2]")]
	describe(df)
end

# ╔═╡ e01fa7a9-16ac-498e-97d3-8c9fe1255f43
md" ## Code 14.29 Find out which one is instrumental variable via dagitty.jl (NOT Implemented)"

# ╔═╡ 48fe8dff-dc91-4996-bfe7-911d2a09b4c8
md"

!!! note

Not implemented in dagitty.jl yet."

# ╔═╡ aef2347f-dea0-4bbb-864c-c7d0d09814c6
let
	g = DAG(:Q => :E, :U => :E, :E => :W, :E => :W)
end

# ╔═╡ 011c2852-91b3-4745-b453-e0ffcdba7f23
md" # 14.4 Social relations as correlated varying effects."

# ╔═╡ 6916ba32-8ebc-4aa7-adf7-f6717fde60e2
md" ## Code 14.30 Load the data"

# ╔═╡ afaf9be1-a557-4b73-9279-f9cf12525958
begin
	kl_dyads = CSV.read(sr_datadir("KosterLeckie.csv"), DataFrame)
	describe(kl_dyads)
end

# ╔═╡ 707fc9b1-ae51-48be-bf77-a031f7d82489
first(kl_dyads,3)

# ╔═╡ 1c03fd5e-0c6a-4118-b11a-0f4d2392f923
md" ## Code 14.31 `m14_7` a model with dyad covariance"

# ╔═╡ 1cd43a15-d361-4e4a-84e2-f1464659a654
# +
kl_data = (
    N = nrow(kl_dyads), 
    N_households = maximum(kl_dyads.hidB),
    did = kl_dyads.did,
    hidA = kl_dyads.hidA,
    hidB = kl_dyads.hidB,
    giftsAB = kl_dyads.giftsAB,
    giftsBA = kl_dyads.giftsBA,
)

# ╔═╡ 2be10e8e-9a44-4b0b-bd81-7e4cdc999afc
@model function m14_7(N, N_households, hidA, hidB, did, giftsAB, giftsBA)
    a ~ Normal()
	#2,4 controls how flat the \rho distribution is .
    ρ_gr ~ LKJ(2, 4)
    σ_gr ~ filldist(Exponential(), 2)
    Σ = (σ_gr .* σ_gr') .* ρ_gr
    gr ~ filldist(MvNormal(Σ), N_households)
    
    # dyad effects (use 2 z values)
    z₁ ~ filldist(Normal(), N)
    z₂ ~ filldist(Normal(), N)
    z = [z₁ z₂]'
    σ_d ~ Exponential()
	#2,8 controls how flat the \rho distribution is
    ρ_d ~ LKJ(2, 4)
    L_ρ_d = cholesky(Symmetric(ρ_d)).L
    d = (σ_d .* L_ρ_d) * z

    λ_AB = exp.(a .+ gr[1, hidA] .+ gr[2, hidB] .+ d[1, did])
    λ_BA = exp.(a .+ gr[1, hidB] .+ gr[2, hidA] .+ d[2, did])
    for i ∈ eachindex(giftsAB)
        giftsAB[i] ~ Poisson(λ_AB[i])
        giftsBA[i] ~ Poisson(λ_BA[i])
    end
    return d
end

# ╔═╡ ee84ac32-58f1-49bc-b705-fbc709e0f11a
begin
	model = m14_7(
	    kl_data.N, kl_data.N_households, kl_data.hidA, kl_data.hidB, 
	    kl_data.did, kl_data.giftsAB, kl_data.giftsBA
	)
	m14_7_ch = sample(model, 
	    NUTS(1000, 0.65, init_ϵ=0.025), 
	    1000)
	m14_7_df = DataFrame(m14_7_ch);
end

# ╔═╡ 8448e4cd-0bce-4426-85db-72a40a279b1d
md" #### Code 14.32 Check posterior estimates of giving vs receiving"

# ╔═╡ 640ac000-dd55-4dda-846f-303404360ab5
describe(m14_7_df[:, r"_gr\[(1,2|2,1|1|2)\]"])

# ╔═╡ 038bc011-279e-492a-bbfc-074630cdff3e
md" ## Code 14.33 generated giving vs receiving"

# ╔═╡ c8d7399e-ad0d-4835-8fa0-1c8ad66e7d34
let
	g = [
	    m14_7_df.a .+ m14_7_df[!,"gr[1,$i]"]
	    for i ∈ 1:25
	]
	r = [
	    m14_7_df.a .+ m14_7_df[!,"gr[2,$i]"]
	    for i ∈ 1:25
	]
	g = hcat(g...)'
	r = hcat(r...)';
	Eg_μ = mean(eachcol(exp.(g)))
	Er_μ = mean(eachcol(exp.(r)));
	
	# Code 14.34
	
	# +
	plot(xlim=(0, 8.6), ylim=(0,8.6), xlab="generalized giving", ylab="generalized receiving")
	plot!(x -> x, c=:black, s=:dash)
	
	for i ∈ 1:25
	    gi = exp.(g[i,:])
	    ri = exp.(r[i,:])
	    Σ = cov([gi ri])
	    μ = [mean(gi), mean(ri)]
	
	    dt = acos(Σ[1,2])
	    xₜ(t) = Σ[1,1]*cos(t + dt/2) + μ[1]
	    yₜ(t) = Σ[2,2]*cos(t - dt/2) + μ[2]
	
	    plot!(xₜ, yₜ, 0, 2π, c=:black, lw=1)
	end
	
	scatter!(Eg_μ, Er_μ, c=:white, msw=1.5)
end

# ╔═╡ 1512c0e0-bee0-4fce-9062-39c60e43f3f8
md" ## Code 14.35 Estimates of dyads"

# ╔═╡ 93a5e590-0ab0-4a13-8944-226258424f7d
describe(m14_7_df[:, r"_d"])

# ╔═╡ aba1a47c-534b-4ce0-b41f-d68c3331207d
md" ## Code 14.36 Residual gifts are strongly correlated within dyads."

# ╔═╡ 2ff1b0f7-4a07-467f-bf0d-069c5b766ed1
#
# Illustrates `generated_quantities` trick to extract values returned from the model

let
	ch = Turing.MCMCChains.get_sections(m14_7_ch, :parameters)
	d_vals = generated_quantities(model, ch)
	
	d_y1 = [r[1,:] for r in d_vals]
	d_y1 = hcat(d_y1...)
	d_y1 = mean.(eachrow(d_y1))
	
	d_y2 = [r[2,:] for r in d_vals]
	d_y2 = hcat(d_y2...)
	d_y2 = mean.(eachrow(d_y2))
	
	scatter(d_y1, d_y2)
end

# ╔═╡ 0f77c94d-011e-4a55-99a1-0ee67acf63fb
md" # 14.5 Continuous categories and the Gaussian process."

# ╔═╡ f9419d58-0770-4715-840d-49b7f7237ba9
md"## Code 14.37 Load the distance matrix of 10 islands in the Kline dataset"

# ╔═╡ 75a8aad7-3460-42bb-a335-a4ca6e6f0435
begin
	islandsDistMatrix = DataFrame(CSV.File("data/islandsDistMatrix.csv"))
	# drop index column
	select!(islandsDistMatrix, Not(:Column1))
	
	# round distances
	show(mapcols(c -> round.(c, digits=1), islandsDistMatrix), allcols=true)
end

# ╔═╡ 765f999b-20f2-440f-87ff-d01ef82cefc7
md"## Code 14.38 Covariance function of linear or squared distance "

# ╔═╡ c12592b9-3c10-4c90-93bc-7f5289f9b90f
let
	plot(x -> exp(-x), xlim=(0, 4), label="linear", lw=2)
	plot!(x -> exp(-(x^2)), label="squared", lw=2)
end

# ╔═╡ 823ad4ee-f4fa-44a8-b3df-2f1704bea9f2
md"## Code 14.39 Tools vs pop and interaction
- Adapted from example here:
- https://discourse.julialang.org/t/gaussian-process-model-with-turing/42453"

# ╔═╡ 9cd414f2-14ab-4a17-822e-321c8e64a9d3
begin
	d_kline = DataFrame(CSV.File("data/Kline2.csv"))
	d_kline[:, "society"] = 1:10;
	size(d_kline)
end

# ╔═╡ 7d6ab552-9096-46cd-9091-ab10ea498ec5
first(d_kline, 5)

# ╔═╡ 3aa50cb9-7f79-4c85-b025-dfae05b2a364
begin
	d_kline_list = (
	    T = d_kline.total_tools,
	    P = d_kline.population,
	    society = d_kline.society,
	    Dmat = Matrix(islandsDistMatrix),
	)
	
	@model function m14_8(T, P, society, Dmat)
	    η² ~ Exponential(2)
	    ρ² ~ Exponential(0.5)
	    a ~ Exponential()
	    b ~ Exponential()
	    g ~ Exponential()
	    
	    Σ = η² * exp.(-ρ² * Dmat^2) + LinearAlgebra.I * (0.01 + η²)
	    k ~ MvNormal(zeros(10), Σ)
	    λ = @. (a*P^b/g)*exp(k[society])
	    @. T ~ Poisson(λ)
	end
	
	Random.seed!(1)
	@time m14_8_ch = sample(m14_8(d_kline_list.T, d_kline_list.P, 
		d_kline_list.society, d_kline_list.Dmat), 
	    NUTS(), 1000)
	m14_8_df = DataFrame(m14_8_ch);
end

# ╔═╡ 91b628c8-884e-43ad-808c-17bdec8be4a0
ess_rhat(m14_8_ch)

# ╔═╡ 740e3801-e3b9-4d61-b205-540cfd837446
md"## Code 14.40 Posterior estimates"

# ╔═╡ d847eb65-1a0f-4dd4-a87a-b2d2b670ccb6
describe(m14_8_df)

# ╔═╡ 4cc25feb-2757-4b8f-8b00-f7fb6203507b
md"## Code 14.41 Posterior covariance function"

# ╔═╡ 54b6c38e-e053-40c4-8d96-5528888e7ac8
begin
	x_seq = range(0, 10, length=100)
	rx_link = (r, x) -> r.η²*exp(-r.ρ²*x^2)
	pmcov = link(m14_8_df, rx_link, x_seq)
	pmcov = hcat(pmcov...)
	pmcov_μ = mean.(eachcol(pmcov))
	
	p_cov_vs_dist = plot(xlab="distance (thousand km)", ylab="covariance", title="Gaussian process posterior estimates",
	    xlim=(0,10), ylim=(0,2))
	plot!(x_seq, pmcov_μ, c=:black, lw=2)
	
	for r ∈ first(eachrow(m14_8_df), 50)
	    plot!(x -> rx_link(r, x), c=:black, alpha=0.3)
	end
	
	p_cov_vs_dist
end

# ╔═╡ 15140a50-7fd3-4138-a5c4-f2e81f036af9
md"## Code 14.42 median estimates of K"

# ╔═╡ f2f97686-af08-48a9-a125-e2da8ac13e18
begin
	@show η²_kline = median(m14_8_df.η²)
	@show ρ²_kline = median(m14_8_df.ρ²)
	@show K_kline = map(d -> η²_kline * exp(-ρ²_kline*d^2), Matrix(islandsDistMatrix))
	K_kline += LinearAlgebra.I * (0.01 + η²_kline);
	K_kline
end

# ╔═╡ 14d862c0-ddb1-4dff-a315-888b076f2f1e
md"## Code 14.43 Convert K to correlation matrix"

# ╔═╡ bd2a7422-e240-466f-9454-60fa17607ed6
begin
	@show Rho = round.(cov2cor(K_kline, sqrt.(diag(K_kline))), digits=2)
	cnames = ["Ml","Ti","SC","Ya","Fi","Tr","Ch","Mn","To","Ha"]
	Rho = DataFrame(Rho, :auto)
	rename!(Rho, cnames)
	show(Rho, allcols=true)
end

# ╔═╡ 1f30d601-4e00-44dd-a6ab-363c431ca875
@model function m14_1(cafe, afternoon, wait)
    a ~ Normal(5, 2)
    b ~ Normal(-1, 0.5)
    σ_cafe ~ filldist(Exponential(), 2)
    Rho ~ LKJ(2, 2)
    # build sigma matrix manually, to avoid numerical errors
#     (σ₁, σ₂) = σ_cafe
#     sc = [[σ₁^2, σ₁*σ₂] [σ₁*σ₂, σ₂^2]]
#     Σ = Rho .* sc
    # the same as above, but shorter and generic
    Σ = (σ_cafe .* σ_cafe') .* Rho
    ab ~ filldist(MvNormal([a,b], Σ), 20)
    a = ab[1,cafe]
    b = ab[2,cafe]
    μ = @. a + b * afternoon
    σ ~ Exponential()
    for i ∈ eachindex(wait)
        wait[i] ~ Normal(μ[i], σ)
    end
end

# ╔═╡ de06a783-c2ff-4f45-8a1e-02977ad31e26
begin
	Random.seed!(1)
	@time m14_1_ch = sample(m14_1(cafes.cafe, cafes.afternoon, cafes.wait), NUTS(), 1000)
	m14_1_df = DataFrame(m14_1_ch);
end

# ╔═╡ 5ca07e4a-bf45-4e3c-9a5b-3b9b7af38020
let
	density(m14_1_df."Rho[1,2]", lab="posterior", lw=2)
	@show LKJ(2,2)
	R = rand(LKJ(2, 2), 10^4);
	density!(getindex.(R, 2), lab="prior", ls=:dash, lw=2)
	plot!(xlab="correlation", ylab="Density")
end

# ╔═╡ 78fe51f6-beea-4155-905d-2d5e6e7d66d7
let
	N_cafes = 20
	gb = groupby(cafes[cafes.afternoon .== 0,:], :cafe)
	global a1 = combine(gb, :wait => mean).wait_mean
	
	gb = groupby(cafes[cafes.afternoon .== 1,:], :cafe)
	global b1 = combine(gb, :wait => mean).wait_mean .- a1
	
	global a2 = [mean(m14_1_df[:, "ab[1,$i]"]) for i ∈ 1:N_cafes]
	global b2 = [mean(m14_1_df[:, "ab[2,$i]"]) for i ∈ 1:N_cafes]
	
	xlim = extrema(a1) .+ (-0.3, 0.3)
	ylim = extrema(b1) .+ (-0.1, 0.1)
	
	global p_cafe = scatter(a1, b1, 
		label="Unpooled estimates", 
		xlab="intercept", ylab="slope", 
		xlim=xlim, ylim=ylim, legend=:topright)
	
	scatter!(a2, b2, mc=:white, label="Pooled estimates")
	
	for (x1,y1,x2,y2) ∈ zip(a1, b1, a2, b2)
	    plot!([x1,x2], [y1,y2], c=:black)
	end
	p_cafe
end

# ╔═╡ 23810d4f-1dd6-4c16-bf71-231b8b4b726d
let
	wait_morning_1 = a1
	wait_afternoon_1 = a1 .+ b1
	wait_morning_2 = a2
	wait_afternoon_2 = a2 .+ b2
	
	global p = scatter(wait_morning_1, wait_afternoon_1, 
		label="Unpooled estimates",
		xlab="morning wait", ylab="afternoon wait", legend=true)
	scatter!(wait_morning_2, wait_afternoon_2, 
		label="Pooled esimates",
		mc=:white)
	
	plot!(x -> x-1, label="y=x-1", s=:dash)

	#connect the two estimates
	for (x1,y1,x2,y2) ∈ zip(wait_morning_1, wait_afternoon_1, wait_morning_2, wait_afternoon_2)
	    plot!([x1,x2], [y1,y2], c=:black)
	end
	p
end

# ╔═╡ 8bb5afba-3f59-4776-9a7b-8df9fed58a90
let
	# posterior mean
	@show ρ = mean(m14_1_df."Rho[1,2]")
	@show μ_a = mean(m14_1_df.a)
	@show μ_b = mean(m14_1_df.b)
	@show σ₁ = mean(m14_1_df."σ_cafe[1]")
	@show σ₂ = mean(m14_1_df."σ_cafe[2]")
	
	# draw ellipses
	@show ρ*σ₁*σ₂
	@show dt = acos(ρ*σ₁*σ₂)
	chi = Chisq(2)
	
	for l ∈ (0.1, 0.3, 0.5, 0.8, 0.99)
	    scale = sqrt(quantile(chi, l))
	    xₜ(t) = scale*σ₁^2*cos(t + dt/2) + μ_a
	    yₜ(t) = scale*σ₂^2*cos(t - dt/2) + μ_b
	
		@show typeof(xₜ)
	    plot!(xₜ, yₜ, 0, 2π, c=:black, alpha=0.3)
	end
	
	p_cafe
end

# ╔═╡ cdeba577-a184-4bb5-97a9-6acf3ff516a3
let
	Random.seed!(1)
	
	# posterior mean
	ρ = mean(m14_1_df."Rho[1,2]")
	μ_a = mean(m14_1_df.a)
	μ_b = mean(m14_1_df.b)
	σ₁ = mean(m14_1_df."σ_cafe[1]")
	σ₂ = mean(m14_1_df."σ_cafe[2]")

	Σ = [[σ₁^2, σ₁*σ₂*ρ] [σ₁*σ₂*ρ, σ₂^2]]
	μ = [μ_a, μ_b]
	v = rand(MvNormal(μ, Σ), 10^4)
	v[2,:] += v[1,:]
	@show Σ₂ = cov(v')
	μ₂ = [μ_a, μ_a+μ_b]
	
	# draw ellipses
	#dt = acos(Σ₂[1,2])
	dt = acos(-ρ)
	chi = Chisq(2)
	
	for l ∈ (0.1, 0.3, 0.5, 0.8, 0.99)
	    scale = sqrt(quantile(chi, l))
	    xₜ(t) = scale*Σ₂[1,1]*cos(t + dt/2) + μ₂[1]
	    yₜ(t) = scale*Σ₂[2,2]*cos(t - dt/2) + μ₂[2]
	
	    plot!(xₜ, yₜ, 0, 2π, c=:black, alpha=0.3)
	end
	
	p
end

# ╔═╡ 42587c2d-785f-4221-906f-b481d3f4b539
md"## Code 14.44 Plot the islands on the map, dot size by log(pop), edge alpha by correlation between islands"

# ╔═╡ 0d803f54-e82f-4ee7-9b31-f5f0d679ff69
begin

	psize = d_kline.logpop ./ maximum(d_kline.logpop)
	psize = @. exp(psize * 1.5) - 2

	labels = map(s -> text(s, 10, :bottom), d_kline.culture)
	islands_on_map = scatter(d_kline.lon2, d_kline.lat, msize=psize*4, texts=labels,
	    xlab="longitude", ylab="lattitude", xlim=(-50, 30))
	for (i, j) ∈ Base.Iterators.product(1:10, 1:10)
	    i >= j && continue
	    plot!(d_kline.lon2[[i,j]], d_kline.lat[[i, j]], c=:black, lw=2,
			alpha=2*(Rho[i,j]^2))
	end
islands_on_map
end

# ╔═╡ 672df617-394c-48ea-b117-f3fb19c20e13
md"## Code 14.45 Plot #Tools vs log(pop), dot sized by log(pop), edge alpha by correlation between islands"

# ╔═╡ cf339bbf-34ac-40c4-9847-5a3118d7775e
begin
	logpop_seq = range(6, 14, length=30)
	λ = link(m14_8_df,  (r, x) -> r.a * exp(x)^r.b / r.g, logpop_seq)
	λ = hcat(λ...)
	λ_median = median.(eachcol(λ))
	λ_pi = PI.(eachcol(λ))
	λ_pi = hcat(λ_pi...)'
	
	p_t_vs_p = scatter(d_kline.logpop, d_kline.total_tools, msize=psize*4, 
		texts=labels, 
	    xlab="log population", ylab="total tools", ylim=(0, 74))
	plot!(logpop_seq, λ_median, c=:black, ls=:dash)
	plot!(logpop_seq, λ_pi[:,1], c=:black, ls=:dash)
	plot!(logpop_seq, λ_pi[:,2], c=:black, ls=:dash)
	
	# overlay correlation
	for (i, j) ∈ Base.Iterators.product(1:10, 1:10)
	    i >= j && continue
	    plot!(d_kline.logpop[[i,j]], d_kline.total_tools[[i, j]],
			c=:black, lw=2, alpha=2*(Rho[i,j]^2))
	end
	p_t_vs_p
end

# ╔═╡ 1ac33e8a-dd1d-4e79-82ce-efe237bace3e
md"## Code 14.46 Non-centered Gaussian Process"

# ╔═╡ 1b5df6ed-d6fa-4db7-ad3a-51c1af13a7fc
begin
	@model function m14_8nc(T, P, society, Dmat)
	    # truncated to prevent cholesky decomposition (requires positive definite matrix) failure
		# and improve ssampling efficiency
	    η² ~ truncated(Exponential(2), lower=0.01, upper=30)
    	ρ² ~ truncated(Exponential(0.5), lower=0.01, upper=30)
	    a ~ Exponential()
	    b ~ Exponential()
	    g ~ Exponential()
	    
	    Σ = η² * exp.(-ρ² * Dmat^2) + LinearAlgebra.I * (0.01 + η²)
	    L_Σ = cholesky(Σ).L
	    z ~ filldist(Normal(0, 1), 10)
	    k = L_Σ .* z 
	    λ = @. (a*P^b/g)*exp(k[society])
	    @. T ~ Poisson(λ)
	end
	
	Random.seed!(1)
	@time m14_8nc_ch = sample(m14_8nc(d_kline_list.T, d_kline_list.P, 
		d_kline_list.society, d_kline_list.Dmat), 
	    NUTS(), 1000);
end

# ╔═╡ a37d8a3b-1be7-4322-aeb3-e96785ce38d5
describe(DataFrame(m14_8nc_ch))

# ╔═╡ 94af3ac3-e468-4aee-b5e9-d0bae5c4fa41
m14_8nc_ch_ess_rhat = ess_rhat(m14_8nc_ch)

# ╔═╡ ace362ef-5676-40af-9b6c-7fda702bb5b8
let
	scatter(ess_rhat(m14_8_ch)[:, :ess], ess_rhat(m14_8nc_ch)[:, :ess],
		xlabel="ESS of centered", ylabel="ESS of non-centered")
	plot!([250, 600], [250, 600])
end

# ╔═╡ 6ad5c52a-eb44-49bf-9796-c89640d9882d
md"## 14.47 Phylogeny regression via Gaussian Process"

# ╔═╡ 0a735ed0-16ab-42a1-b8d6-e21c4cc010b3
md" ### 14.47.1 Load the data"

# ╔═╡ abdbfd66-c74b-48bc-9c33-c0c9c4c522ae
d = DataFrame(CSV.File("data/Primates301.csv", missingstring="NA"))

# ╔═╡ 8979364d-dcdc-4ef6-bec3-04b8c9036347
describe(d)

# ╔═╡ 744877ee-e7ec-4d77-883b-1437578b0e62
md"## 14.48 Trim the missing data"

# ╔═╡ f1d976dc-9a74-4a84-be45-f25d193a6f43
begin
	dstan = d[completecases(d, ["group_size", "body", "brain"]), :]
	spp_obs = dstan.name;
end

# ╔═╡ 862a30ad-c28c-4145-9ac1-59c09ba08cab
md" ## 14.49 Ordinary regression: Brain size ~ Mass + Group size
- The σ_sq estimate (0.22) is higher than the book & PyMC3 (0.05).
- Other estimates are similar."

# ╔═╡ 9468f5d9-3eb0-4cd6-a40b-2401712991cc
begin
	dat_list = (
	    N_spp = nrow(dstan),
	    M = standardize(ZScoreTransform, log.(dstan.body)),
	    B = standardize(ZScoreTransform, log.(dstan.brain)),
	    G = standardize(ZScoreTransform, log.(dstan.group_size)),
	)
	
	@model function m14_9(N_spp, M, B, G)
	    σ_sq ~ Exponential()
	    bM ~ Normal(0, 0.5)
	    bG ~ Normal(0, 0.5)
	    a ~ Normal()
	    μ = @. a + bM*M + bG * G
	    B ~ MvNormal(μ, σ_sq)
	end
	
	Random.seed!(1)
	@time m14_9_ch = sample(m14_9(dat_list...), NUTS(), 1000)
	m14_9_df = DataFrame(m14_9_ch)
	describe(m14_9_df)
end

# ╔═╡ a591c017-bffd-49d8-aa3d-c7c1b40100fd
md"## Code 14.50 Plot the implied covariance matrix vs the distance matrix"

# ╔═╡ 8fa9f394-bae7-4cd1-91dc-1e444bd296c3
begin
	cov_mat = DataFrame(CSV.File("data/Primates301_vcov_matrix.csv"))
	dist_mat = DataFrame(CSV.File("data/Primates301_distance_matrix.csv"))
	
	# Drop index columns
	select!(cov_mat, Not(:Column1))
	select!(dist_mat, Not(:Column1));
	
	p_dist_vs_cov = scatter(Matrix(dist_mat), Matrix(cov_mat), c=:black, ms=2, 
		xlabel="phylogeny distance", ylabel="covariance")
	#display("image/png", p_dist_vs_cov)
end

# ╔═╡ 0b2ace5b-2e9a-4455-8068-9207dcc2f8f3
first(dist_mat, 3)

# ╔═╡ 3098cdb9-4802-466c-a09c-f106dd4b50fb
first(cov_mat, 5)

# ╔═╡ 7452a574-2021-45b4-b907-fdc39bffe9b3
md"## 14.51 `m14_10`: Gaussian process using the Quadratic kernel (the covariance matrix).
- All estimates are similar to the book or PyMC3.
- Effect of group size is now insignificant!"

# ╔═╡ af4eeae4-1d1b-460c-93b8-1e9ac23e9d60
begin
	# reorder the covariance matrix so that the rows/columns match the rest of the data.
	V_inds = [
	    findfirst(x -> x == n, names(cov_mat))
	    for n in spp_obs
	];
	
	V_dat = Matrix(cov_mat[V_inds, V_inds])
	#convert it into correlation matrix.
	R = V_dat ./ maximum(V_dat);
	
	@model function m14_10(N_spp, M, B, G, R)
	    σ_sq ~ Exponential()
	    bM ~ Normal(0, 0.5)
	    bG ~ Normal(0, 0.5)
	    a ~ Normal()
	    μ = @. a + bM*M + bG * G
	    Σ = R * σ_sq
	    B ~ MvNormal(μ, Σ)
	end
	
	Random.seed!(1)
	@time m14_10_ch = sample(m14_10(dat_list..., R), NUTS(), 1000)
	m14_10_df = DataFrame(m14_10_ch)
	describe(m14_10_df)
end

# ╔═╡ afa9b842-ca47-48bb-bd2f-65f9bf3f2ac6
V_inds

# ╔═╡ ed4327aa-160f-4b64-9548-cb0422890a2e
V_dat[1:3, :]

# ╔═╡ 7e40e00a-4b2f-4f9e-82f0-847e17e2423c
spp_obs

# ╔═╡ 6c699793-ed34-400f-b4de-31ccef89cb60
md"## 14.52 OU process kernel (=Exponential distance kernel)
- After truncating the range in sampling η² and ρ² to [0.01, 50] (was above 1 and 3 respectively), η² estimate (0.0135, was 1.01) is similar to the book (0.03). PyMC3 estimate of η² (1.08) is higher, not sure why."

# ╔═╡ df368764-5237-4cbb-80c8-eac7c13844da
begin
	# reorder the distance matrix so that the rows/columns match the rest of the data.
	D_inds = [
		findfirst(x -> x == n, names(dist_mat))
		for n in spp_obs
	];
	
	D_dat = Matrix(dist_mat[D_inds, D_inds])
	# turn it into correlation matrix.
	D_dat ./= maximum(D_dat);
end

# ╔═╡ e19912ef-e590-4caa-ae78-6fd35c6bee56
begin
	
	@model function m14_11(N_spp, M, B, G, D_dat)
	    bM ~ Normal(0, 0.5)
	    bG ~ Normal(0, 0.5)
	    a ~ Normal()
	    μ = @. a + bM*M + bG * G
	    
	    η² ~ truncated(Normal(1, 0.25), lower=0.01, upper=50)
	    ρ² ~ truncated(Normal(3, 0.25), lower=0.01, upper=50)
	    
	    Σ = η² * exp.(-ρ² * D_dat) + LinearAlgebra.I * (0.01 + η²)
	    B ~ MvNormal(μ, Σ)
	end
	
	Random.seed!(1)
	@time m14_11_ch = sample(m14_11(dat_list..., D_dat), NUTS(500, 0.65, init_ϵ=0.4), 4000)
	m14_11_df = DataFrame(m14_11_ch)
	describe(m14_11_df)
end

# ╔═╡ 0bbb0ce8-01bd-4dfd-ac9d-060d1a00d6fb
first(m14_11_df, 30)

# ╔═╡ 6c61f30f-0227-4551-85ee-2a7dcea84558
md"## 14.53 Posterior estimates vs prior"

# ╔═╡ 89d2c59f-be30-422b-bdd9-df7a125b949b
begin
	plot(xlim=(0, maximum(D_dat)), ylim=(0, 1.5),
		xlab="phylogenetic distance", ylab="covariance")
	# posterior estimates
	for r in first(eachrow(m14_11_df), 30)
		plot!(x -> r.η² * exp(-r.ρ²*x), c=:blue, alpha=0.5)
	end
	
	# Prior sampling	
	Random.seed!(1)
	η_vec = rand(Normal(1, 0.25), 1000)
	ρ_vec = rand(Normal(3, 0.25), 1000)
	d_seq = range(0, 1, length=50)
	
	K = [
	    [
	        η² * exp(-ρ²*d)
	        for d ∈ d_seq
	    ]
	    for (η², ρ²) ∈ zip(η_vec, ρ_vec)
	]
	K = hcat(K...)'
	
	K_μ = mean.(eachcol(K))
	K_pi = PI.(eachcol(K))
	K_pi = vcat(K_pi'...)
	
	plot!(d_seq, [K_μ K_μ], fillrange=K_pi, fillalpha=0.2, c=:black)
	annotate!([
	        (0.5, 0.5, text("prior", 12)),
	        (0.2, 0.2, text("posterior", 12))
	])
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
Dagitty = "d56128e0-8113-48cd-82a0-fc808dc30d4b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
DrWatson = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Logging = "56ddb016-857b-54e1-b83d-db4d58db5568"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
StatisticalRethinking = "2d09df54-9d0f-5258-8220-54c2a3d4fbee"
StatisticalRethinkingPlots = "e1a513d0-d9d9-49ff-a6dd-9d2e9db473da"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
StatsPlots = "f3b207a7-027a-5e70-b257-86293d7955fd"
Turing = "fce5fe82-541a-59a6-adf8-730c64b5f9a0"

[compat]
CSV = "~0.10.12"
Dagitty = "~0.0.1"
DataFrames = "~1.6.1"
Distributions = "~0.25.107"
DrWatson = "~2.15.0"
PlutoUI = "~0.7.23"
StatisticalRethinking = "~4.8.0"
StatisticalRethinkingPlots = "~1.1.0"
StatsBase = "~0.34.2"
StatsPlots = "~0.15.6"
Turing = "~0.30.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.0-rc4"
manifest_format = "2.0"
project_hash = "a8365073e8d79e9019d612e7800f422753be2cf3"

[[deps.ADTypes]]
git-tree-sha1 = "016833eb52ba2d6bea9fcb50ca295980e728ee24"
uuid = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
version = "0.2.7"

[[deps.ANSIColoredPrinters]]
git-tree-sha1 = "574baf8110975760d391c710b6341da1afa48d8c"
uuid = "a4c015fc-c6ff-483c-b24f-f7ea428134e9"
version = "0.0.1"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractMCMC]]
deps = ["BangBang", "ConsoleProgressMonitor", "Distributed", "FillArrays", "LogDensityProblems", "Logging", "LoggingExtras", "ProgressLogging", "Random", "StatsBase", "TerminalLoggers", "Transducers"]
git-tree-sha1 = "bb311c0742ec2f9aebe00d2ffe225d80eeadf749"
uuid = "80f14c24-f653-4e6a-9b94-39d6b0f70001"
version = "5.3.0"

[[deps.AbstractPPL]]
deps = ["AbstractMCMC", "DensityInterface", "Random", "Setfield"]
git-tree-sha1 = "9774889eac07c2e342e547b5c5c8ae5a2ce5c80b"
uuid = "7a57a42e-76ec-4ea3-a279-07e840d6d9cf"
version = "0.7.1"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "InverseFunctions", "LinearAlgebra", "MacroTools", "Markdown"]
git-tree-sha1 = "b392ede862e506d451fc1616e79aa6f4c673dab8"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.38"

    [deps.Accessors.extensions]
    AccessorsAxisKeysExt = "AxisKeys"
    AccessorsDatesExt = "Dates"
    AccessorsIntervalSetsExt = "IntervalSets"
    AccessorsStaticArraysExt = "StaticArrays"
    AccessorsStructArraysExt = "StructArrays"
    AccessorsTestExt = "Test"
    AccessorsUnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    Requires = "ae029012-a4dd-5104-9daa-d747884805df"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "6a55b747d1812e699320963ffde36f1ebdda4099"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.0.4"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AdvancedHMC]]
deps = ["AbstractMCMC", "ArgCheck", "DocStringExtensions", "InplaceOps", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "ProgressMeter", "Random", "Requires", "Setfield", "SimpleUnPack", "Statistics", "StatsBase", "StatsFuns"]
git-tree-sha1 = "dfa0e3508fc3df81d28624b328f3b937c1df8bc2"
uuid = "0bf59076-c3b1-5ca4-86bd-e02cd72cde3d"
version = "0.6.1"

    [deps.AdvancedHMC.extensions]
    AdvancedHMCCUDAExt = "CUDA"
    AdvancedHMCMCMCChainsExt = "MCMCChains"
    AdvancedHMCOrdinaryDiffEqExt = "OrdinaryDiffEq"

    [deps.AdvancedHMC.weakdeps]
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    MCMCChains = "c7f686f2-ff18-58e9-bc7b-31028e88f75d"
    OrdinaryDiffEq = "1dea7af3-3e70-54e6-95c3-0bf5283fa5ed"

[[deps.AdvancedMH]]
deps = ["AbstractMCMC", "Distributions", "FillArrays", "LinearAlgebra", "LogDensityProblems", "Random", "Requires"]
git-tree-sha1 = "66ac4c7b320d2434f04d48116db02e73e6dabc8b"
uuid = "5b7e9947-ddc0-4b3f-9b55-0d8042f74170"
version = "0.8.3"
weakdeps = ["DiffResults", "ForwardDiff", "MCMCChains", "StructArrays"]

    [deps.AdvancedMH.extensions]
    AdvancedMHForwardDiffExt = ["DiffResults", "ForwardDiff"]
    AdvancedMHMCMCChainsExt = "MCMCChains"
    AdvancedMHStructArraysExt = "StructArrays"

[[deps.AdvancedPS]]
deps = ["AbstractMCMC", "Distributions", "Random", "Random123", "Requires", "StatsFuns"]
git-tree-sha1 = "672f7ce648e06f93fceefde463c5855d77b6915a"
uuid = "576499cb-2369-40b2-a588-c64705576edc"
version = "0.5.4"
weakdeps = ["Libtask"]

    [deps.AdvancedPS.extensions]
    AdvancedPSLibtaskExt = "Libtask"

[[deps.AdvancedVI]]
deps = ["ADTypes", "Bijectors", "DiffResults", "Distributions", "DistributionsAD", "DocStringExtensions", "ForwardDiff", "LinearAlgebra", "ProgressMeter", "Random", "Requires", "StatsBase", "StatsFuns", "Tracker"]
git-tree-sha1 = "3e97de1a2ccce08978cd80570d8cbb9ff3f08bd3"
uuid = "b5ca4192-6429-45e5-a2d9-87aec30a685c"
version = "0.2.6"

    [deps.AdvancedVI.extensions]
    AdvancedVIEnzymeExt = ["Enzyme"]
    AdvancedVIFluxExt = ["Flux"]
    AdvancedVIReverseDiffExt = ["ReverseDiff"]
    AdvancedVIZygoteExt = ["Zygote"]

    [deps.AdvancedVI.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "f87e559f87a45bece9c9ed97458d3afe98b1ebb9"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.1.0"

[[deps.Arpack]]
deps = ["Arpack_jll", "Libdl", "LinearAlgebra", "Logging"]
git-tree-sha1 = "9b9b347613394885fd1c8c7729bfc60528faa436"
uuid = "7d9fca2a-8960-54d3-9f78-7d1dccf2cb97"
version = "0.5.4"

[[deps.Arpack_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "OpenBLAS_jll", "Pkg"]
git-tree-sha1 = "5ba6c757e8feccf03a1554dfaf3e26b3cfc7fd5e"
uuid = "68821587-b530-5797-8361-c406ea357684"
version = "3.5.1+1"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "3640d077b6dafd64ceb8fd5c1ec76f7ca53bcf76"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.16.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = "CUDSS"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Atomix]]
deps = ["UnsafeAtomics"]
git-tree-sha1 = "c06a868224ecba914baa6942988e2f2aade419be"
uuid = "a9b6321e-bd34-4604-b9c9-b65b8de01458"
version = "0.1.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.BangBang]]
deps = ["Compat", "ConstructionBase", "InitialValues", "LinearAlgebra", "Requires", "Setfield", "Tables"]
git-tree-sha1 = "7aa7ad1682f3d5754e3491bb59b8103cae28e3a3"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.3.40"

    [deps.BangBang.extensions]
    BangBangChainRulesCoreExt = "ChainRulesCore"
    BangBangDataFramesExt = "DataFrames"
    BangBangStaticArraysExt = "StaticArrays"
    BangBangStructArraysExt = "StructArrays"
    BangBangTypedTablesExt = "TypedTables"

    [deps.BangBang.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    TypedTables = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.BenchmarkTools]]
deps = ["JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "f1dff6729bc61f4d49e140da1af55dcd1ac97b2f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.5.0"

[[deps.Bijectors]]
deps = ["ArgCheck", "ChainRules", "ChainRulesCore", "ChangesOfVariables", "Compat", "Distributions", "DocStringExtensions", "Functors", "InverseFunctions", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "MappedArrays", "Random", "Reexport", "Requires", "Roots", "SparseArrays", "Statistics"]
git-tree-sha1 = "92edc3544607c4fda1b30357910597e2a70dc5ea"
uuid = "76274a88-744f-5084-9051-94815aaf08c4"
version = "0.13.18"

    [deps.Bijectors.extensions]
    BijectorsDistributionsADExt = "DistributionsAD"
    BijectorsEnzymeExt = "Enzyme"
    BijectorsForwardDiffExt = "ForwardDiff"
    BijectorsLazyArraysExt = "LazyArrays"
    BijectorsReverseDiffExt = "ReverseDiff"
    BijectorsTapirExt = "Tapir"
    BijectorsTrackerExt = "Tracker"
    BijectorsZygoteExt = "Zygote"

    [deps.Bijectors.weakdeps]
    DistributionsAD = "ced4e74d-a319-5a8a-b0ac-84af2272839c"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tapir = "07d77754-e150-4737-8c94-cd238a1fb45b"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "f21cfd4950cb9f0587d5067e69405ad2acd27b87"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.6"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9e2a6b69137e6969bab0152632dcb3bc108c8bdd"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+1"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CPUSummary]]
deps = ["CpuId", "IfElse", "PrecompileTools", "Static"]
git-tree-sha1 = "5a97e67919535d6841172016c9530fd69494e5ec"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.6"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "6c834533dc1fabd820c1db03c839bf97e45a3fab"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.14"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a2f1c8c668c8e3cb4cca4e57a8efdb09067bb3fd"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.0+2"

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "SparseInverseSubset", "Statistics", "StructArrays", "SuiteSparse"]
git-tree-sha1 = "be227d253d132a6d57f9ccf5f67c0fb6488afd87"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.71.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "3e4b134270b372f2ed4d4d0e936aabaefc1802bc"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.ChangesOfVariables]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "799b25ca3a8a24936ae7b5c52ad194685fc3e6ef"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.9"
weakdeps = ["InverseFunctions", "Test"]

    [deps.ChangesOfVariables.extensions]
    ChangesOfVariablesInverseFunctionsExt = "InverseFunctions"
    ChangesOfVariablesTestExt = "Test"

[[deps.Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "Random", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "9ebb045901e9bbf58767a9f34ff89831ed711aae"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.15.7"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "bce6804e5e6044c6daab27bb533d1295e4a2e759"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.6"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b5278586822443594ff615963b0c09755771b3e0"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.26.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "32a2b8af383f11cbb65803883837a149d10dfe8a"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.10.12"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSolve]]
git-tree-sha1 = "0eee5eb66b1cf62cd6ad1b460238e60e4b09400c"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.4"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.CommonWorldInvalidations]]
git-tree-sha1 = "ae52d1c52048455e85a387fbee9be553ec2b68d0"
uuid = "f70d9fcc-98c5-4d4a-abd7-e4cdeebd8ca8"
version = "1.0.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.Compose]]
deps = ["Base64", "Colors", "DataStructures", "Dates", "IterTools", "JSON", "LinearAlgebra", "Measures", "Printf", "Random", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "bf6570a34c850f99407b494757f5d7ad233a7257"
uuid = "a81c6b42-2e10-5240-aca2-a61377ecd94b"
version = "0.9.5"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "ea32b83ca4fefa1768dc84e504cc0a94fb1ab8d1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.2"

[[deps.ConsoleProgressMonitor]]
deps = ["Logging", "ProgressMeter"]
git-tree-sha1 = "3ab7b2136722890b9af903859afcf457fa3059e8"
uuid = "88cd18e8-d9cc-4ea6-8889-5259c0d15c8b"
version = "0.1.2"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.Contour]]
git-tree-sha1 = "439e35b0b36e2e5881738abc8857bd92ad6ff9a8"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.3"

[[deps.CpuId]]
deps = ["Markdown"]
git-tree-sha1 = "fcbb72b032692610bfbdb15018ac16a36cf2e406"
uuid = "adafc99b-e345-5852-983c-f28acb93d879"
version = "0.3.1"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.Dagitty]]
deps = ["BenchmarkTools", "Combinatorics", "Compose", "DataStructures", "Documenter", "GraphPlot", "LightGraphs", "Test"]
git-tree-sha1 = "c9746c7593c784cdd5502f2fb5a0dfdbfeb8eebf"
uuid = "d56128e0-8113-48cd-82a0-fc808dc30d4b"
version = "0.0.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Dbus_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fc173b380865f70627d7dd1190dc2fce6cc105af"
uuid = "ee1fde0b-3d02-5ea6-8484-8dfef6360eab"
version = "1.14.10+0"

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "66c4c81f259586e8f002eacebc177e1fb06363b0"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.11"
weakdeps = ["ChainRulesCore", "SparseArrays"]

    [deps.Distances.extensions]
    DistancesChainRulesCoreExt = "ChainRulesCore"
    DistancesSparseArraysExt = "SparseArrays"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "d7477ecdafb813ddee2ae727afa94e9dcb5f3fb0"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.112"
weakdeps = ["ChainRulesCore", "DensityInterface", "Test"]

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

[[deps.DistributionsAD]]
deps = ["Adapt", "ChainRules", "ChainRulesCore", "Compat", "Distributions", "FillArrays", "LinearAlgebra", "PDMats", "Random", "Requires", "SpecialFunctions", "StaticArrays", "StatsFuns", "ZygoteRules"]
git-tree-sha1 = "f4dd7727b07b4b7fff5ff4149118ee06e83dfab7"
uuid = "ced4e74d-a319-5a8a-b0ac-84af2272839c"
version = "0.6.55"

    [deps.DistributionsAD.extensions]
    DistributionsADForwardDiffExt = "ForwardDiff"
    DistributionsADLazyArraysExt = "LazyArrays"
    DistributionsADReverseDiffExt = "ReverseDiff"
    DistributionsADTrackerExt = "Tracker"

    [deps.DistributionsAD.weakdeps]
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Documenter]]
deps = ["ANSIColoredPrinters", "Base64", "Dates", "DocStringExtensions", "IOCapture", "InteractiveUtils", "JSON", "LibGit2", "Logging", "Markdown", "REPL", "Test", "Unicode"]
git-tree-sha1 = "39fd748a73dce4c05a9655475e437170d8fb1b67"
uuid = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
version = "0.27.25"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DrWatson]]
deps = ["Dates", "FileIO", "JLD2", "LibGit2", "MacroTools", "Pkg", "Random", "Requires", "Scratch", "UnPack"]
git-tree-sha1 = "2d6e724fab0c57284b3d1a7473a5a62ce6aba471"
uuid = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
version = "2.15.0"

[[deps.DynamicPPL]]
deps = ["ADTypes", "AbstractMCMC", "AbstractPPL", "BangBang", "Bijectors", "Compat", "ConstructionBase", "Distributions", "DocStringExtensions", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "MacroTools", "OrderedCollections", "Random", "Requires", "Setfield", "Test"]
git-tree-sha1 = "839b5a5257047c2fe47946e84a706e37d9cfee27"
uuid = "366bfd00-2699-11ea-058f-f148b4cae6d8"
version = "0.24.11"

    [deps.DynamicPPL.extensions]
    DynamicPPLChainRulesCoreExt = ["ChainRulesCore"]
    DynamicPPLEnzymeCoreExt = ["EnzymeCore"]
    DynamicPPLForwardDiffExt = ["ForwardDiff"]
    DynamicPPLMCMCChainsExt = ["MCMCChains"]
    DynamicPPLReverseDiffExt = ["ReverseDiff"]
    DynamicPPLZygoteRulesExt = ["ZygoteRules"]

    [deps.DynamicPPL.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    MCMCChains = "c7f686f2-ff18-58e9-bc7b-31028e88f75d"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    ZygoteRules = "700de1a5-db45-46bc-99cf-38207098b444"

[[deps.EllipticalSliceSampling]]
deps = ["AbstractMCMC", "ArrayInterface", "Distributions", "Random", "Statistics"]
git-tree-sha1 = "e611b7fdfbfb5b18d5e98776c30daede41b44542"
uuid = "cad2338a-1db2-11e9-3401-43bc07c9ede2"
version = "2.0.0"

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.EpollShim_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8e9441ee83492030ace98f9789a654a6d0b1f643"
uuid = "2702e6a9-849d-5ed8-8c21-79e8b8f9ee43"
version = "0.0.20230411+0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "dcb08a0d93ec0b1cdc4af184b26b591e9695423a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.10"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1c6317308b9dc757616f0b5cb379db10494443a7"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.6.2+0"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.Expronicon]]
deps = ["MLStyle", "Pkg", "TOML"]
git-tree-sha1 = "fc3951d4d398b5515f91d7fe5d45fc31dccb3c9b"
uuid = "6b7a57c9-7cc1-4fdf-b7f5-e857abae3636"
version = "0.8.5"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "53ebe7511fa11d33bec688a9178fac4e49eeee00"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.2"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "466d45dc38e15794ec7d5d63ec03d776a9aff36e"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.4+1"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "4820348781ae578893311153d69049a93d05f39d"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.8.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4d81ed14783ec49ce9f2e168208a12ce1815aa25"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "82d8afa92ecf4b52d78d869f038ebfb881267322"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "7878ff7172a8e6beedd1dea14bd27c3c6340d361"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.22"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Setfield", "SparseArrays"]
git-tree-sha1 = "f9219347ebf700e77ca1d48ef84e4a82a6701882"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.24.0"

    [deps.FiniteDiff.extensions]
    FiniteDiffBandedMatricesExt = "BandedMatrices"
    FiniteDiffBlockBandedMatricesExt = "BlockBandedMatrices"
    FiniteDiffStaticArraysExt = "StaticArrays"

    [deps.FiniteDiff.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "db16beca600632c95fc8aca29890d83788dd8b23"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.96+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "cf0fe81336da9fb90944683b8c41984b08793dad"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.36"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "5c1d8ae0efc6c2e7b1fc502cbe25def8f661b7bc"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.2+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1ed150b39aebcc805c26b93a8d0122c940f64ce2"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.14+0"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.FunctionWrappersWrappers]]
deps = ["FunctionWrappers"]
git-tree-sha1 = "b104d487b34566608f8b4e1c39fb0b10aa279ff8"
uuid = "77dc65aa-8811-40c2-897b-53d922fa7daf"
version = "0.1.3"

[[deps.Functors]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "64d8e93700c7a3f28f717d265382d52fac9fa1c1"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.4.12"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll", "libdecor_jll", "xkbcommon_jll"]
git-tree-sha1 = "532f9126ad901533af1d4f5c198867227a7bb077"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.4.0+1"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "ec632f177c0d990e64d955ccc1b8c04c485a0950"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.6"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Qt6Wayland_jll", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "629693584cef594c3f6f99e76e7a7ad17e60e8d5"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.7"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a8863b69c2a0859f2c2c87ebdc4c6712e88bdf0d"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.7+0"

[[deps.GenericSchur]]
deps = ["LinearAlgebra", "Printf"]
git-tree-sha1 = "af49a0851f8113fcfae2ef5027c6d49d0acec39b"
uuid = "c145ed77-6b09-5dd9-b285-bf645a82121e"
version = "0.5.4"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "7c82e6a6cd34e9d935e9aa4051b66c6ff3af59ba"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.80.2+0"

[[deps.GraphPlot]]
deps = ["ArnoldiMethod", "ColorTypes", "Colors", "Compose", "DelimitedFiles", "LightGraphs", "LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "dd8f15128a91b0079dfe3f4a4a1e190e54ac7164"
uuid = "a2cc645c-3eea-5389-862e-a155d0052231"
version = "0.4.4"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "d1d712be3164d61d1fb98e7ce9bcbc6cc06b45ed"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.8"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll"]
git-tree-sha1 = "401e4f3f30f43af2c8478fc008da50096ea5240f"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "8.3.1+0"

[[deps.HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Static"]
git-tree-sha1 = "8e070b599339d622e9a081d17230d74a5c473293"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.17"

[[deps.HypergeometricFunctions]]
deps = ["LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "7c4195be1649ae622304031ed46a2f4df989f1eb"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.24"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InlineStrings]]
git-tree-sha1 = "45521d31238e87ee9f9732561bfee12d4eebd52d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.2"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InplaceOps]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "50b41d59e7164ab6fda65e71049fee9d890731ff"
uuid = "505f98c9-085e-5b2c-8e89-488be7bf1f34"
version = "0.3.0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "10bd689145d2c3b2a9844005d01087cc1194e79e"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.2.1+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"
weakdeps = ["Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalSets]]
git-tree-sha1 = "dba9ddf07f77f60450fe5d2e2beb9854d9a49bd0"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.10"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "PrecompileTools", "Requires", "TranscodingStreams"]
git-tree-sha1 = "a0746c21bdc986d0dc293efa6b1faee112c37c28"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.53"

[[deps.JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "39d64b09147620f5ffbf6b2d3255be3c901bec63"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.8"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "f389674c99bfcde17dc57454011aa44d5a260a40"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.6.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "25ee0be4d43d0269027024d75a24c24d6c6e590c"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.4+0"

[[deps.KernelAbstractions]]
deps = ["Adapt", "Atomix", "InteractiveUtils", "MacroTools", "PrecompileTools", "Requires", "StaticArrays", "UUIDs", "UnsafeAtomics", "UnsafeAtomicsLLVM"]
git-tree-sha1 = "5126765c5847f74758c411c994312052eb7117ef"
uuid = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
version = "0.9.27"

    [deps.KernelAbstractions.extensions]
    EnzymeExt = "EnzymeCore"
    LinearAlgebraExt = "LinearAlgebra"
    SparseArraysExt = "SparseArrays"

    [deps.KernelAbstractions.weakdeps]
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "7d703202e65efa1369de1279c162b915e245eed1"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.9"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "170b660facf5df5de098d866564877e119141cbd"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.2+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Preferences", "Printf", "Requires", "Unicode"]
git-tree-sha1 = "4ad43cb0a4bb5e5b1506e1d1f48646d7e0c80363"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "9.1.2"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "05a8bd5a42309a9ec82f700876903abce1017dd3"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.34+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "78211fb6cbc872f77cad3fc0b6cf647d923f4929"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "18.1.7+0"

[[deps.LRUCache]]
git-tree-sha1 = "b3cc6698599b10e652832c2f23db3cab99d51b59"
uuid = "8ac3fa9e-de4c-5943-b1dc-09c6b5f20637"
version = "1.6.1"
weakdeps = ["Serialization"]

    [deps.LRUCache.extensions]
    SerializationExt = ["Serialization"]

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "854a9c268c43b77b0a27f22d7fab8d33cdb3a731"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.2+1"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "ce5f5621cac23a86011836badfedf664a612cee4"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.5"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SparseArraysExt = "SparseArrays"
    SymEngineExt = "SymEngine"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"

[[deps.LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "a9eaadb366f5493a5654e843864c13d8b107548c"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.17"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LeftChildRightSiblingTrees]]
deps = ["AbstractTrees"]
git-tree-sha1 = "fb6803dafae4a5d62ea5cab204b1e657d9737e7f"
uuid = "1d6d02ad-be62-4b6b-8a6d-2f90e265016e"
version = "0.2.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll"]
git-tree-sha1 = "9fd170c4bbfd8b935fdc5f8b7aa33532c991a673"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.11+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fbb1f2bef882392312feb1ede3615ddc1e9b99ed"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.49.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f9557a255370125b405568f9767d6d195822a175"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0c4f9c4f1a50d8f35048fa0532dabbadf702f81e"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.40.1+0"

[[deps.Libtask]]
deps = ["FunctionWrappers", "LRUCache", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "ed1f362b3fd13f00b65e61d98669c652c17663ab"
uuid = "6f1fad26-d15e-5dc8-ae53-837a1d7b8c9f"
version = "0.8.7"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "2da088d113af58221c52828a80378e16be7d037a"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.5.1+1"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "5ee6203157c120d79034c748a2acba45b82b8807"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.40.1+0"

[[deps.LightGraphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "432428df5f360964040ed60418dd5601ecd240b6"
uuid = "093fc24a-ae57-5d10-9952-331d41423f4d"
version = "1.3.5"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "e4c3be53733db1051cc15ecf573b1042b3a712a1"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.3.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LogDensityProblems]]
deps = ["ArgCheck", "DocStringExtensions", "Random"]
git-tree-sha1 = "f9a11237204bc137617194d79d813069838fcf61"
uuid = "6fdf6af0-433a-55f7-b3ed-c6c6e0b8df7c"
version = "2.1.1"

[[deps.LogDensityProblemsAD]]
deps = ["DocStringExtensions", "LogDensityProblems", "Requires", "SimpleUnPack"]
git-tree-sha1 = "98cad2db1c46f2fff70a5e305fb42c97a251422a"
uuid = "996a588d-648d-4e1f-a8f0-a84b347e47b1"
version = "1.9.0"

    [deps.LogDensityProblemsAD.extensions]
    LogDensityProblemsADADTypesExt = "ADTypes"
    LogDensityProblemsADEnzymeExt = "Enzyme"
    LogDensityProblemsADFiniteDifferencesExt = "FiniteDifferences"
    LogDensityProblemsADForwardDiffBenchmarkToolsExt = ["BenchmarkTools", "ForwardDiff"]
    LogDensityProblemsADForwardDiffExt = "ForwardDiff"
    LogDensityProblemsADReverseDiffExt = "ReverseDiff"
    LogDensityProblemsADTrackerExt = "Tracker"
    LogDensityProblemsADZygoteExt = "Zygote"

    [deps.LogDensityProblemsAD.weakdeps]
    ADTypes = "47edcb42-4c32-4615-8424-f2b9edc5f35b"
    BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"
    FiniteDifferences = "26cc04aa-876d-5657-8c51-4c34ba976000"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "a2d09619db4e765091ee5c6ffe8872849de0feea"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.28"
weakdeps = ["ChainRulesCore", "ChangesOfVariables", "InverseFunctions"]

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "c1dd6d7978c12545b4179fb6153b9250c96b0075"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.3"

[[deps.MCMCChains]]
deps = ["AbstractMCMC", "AxisArrays", "Dates", "Distributions", "IteratorInterfaceExtensions", "KernelDensity", "LinearAlgebra", "MCMCDiagnosticTools", "MLJModelInterface", "NaturalSort", "OrderedCollections", "PrettyTables", "Random", "RecipesBase", "Statistics", "StatsBase", "StatsFuns", "TableTraits", "Tables"]
git-tree-sha1 = "d28056379864318172ff4b7958710cfddd709339"
uuid = "c7f686f2-ff18-58e9-bc7b-31028e88f75d"
version = "6.0.6"

[[deps.MCMCDiagnosticTools]]
deps = ["AbstractFFTs", "DataAPI", "DataStructures", "Distributions", "LinearAlgebra", "MLJModelInterface", "Random", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "8ba8b1840d3ab5b38e7c71c23c3193bb5cbc02b5"
uuid = "be115224-59cd-429b-ad48-344e309966f0"
version = "0.3.10"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "f046ccd0c6db2832a9f639e2c669c6fe867e5f4f"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.2.0+0"

[[deps.MLJModelInterface]]
deps = ["Random", "ScientificTypesBase", "StatisticalTraits"]
git-tree-sha1 = "ceaff6618408d0e412619321ae43b33b40c1a733"
uuid = "e80e1ace-859a-464e-9ed9-23947d8ae3ea"
version = "1.11.0"

[[deps.MLStyle]]
git-tree-sha1 = "bc38dff0548128765760c79eb7388a4b37fae2c8"
uuid = "d8e11817-5142-5d16-987a-aa16d5891078"
version = "0.4.17"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "2fa9ee3e63fd3a4f7a9a4f4744a52f4856de82df"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.13"

[[deps.ManualMemory]]
git-tree-sha1 = "bcaef4fc7a0cfe2cba636d84cda54b5e4e4ca3cd"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.8"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.MicroCollections]]
deps = ["BangBang", "InitialValues", "Setfield"]
git-tree-sha1 = "629afd7d10dbc6935ec59b32daeb33bc4460a42e"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.1.4"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MonteCarloMeasurements]]
deps = ["Distributed", "Distributions", "ForwardDiff", "GenericSchur", "LinearAlgebra", "MacroTools", "Random", "RecipesBase", "Requires", "SLEEFPirates", "StaticArrays", "Statistics", "StatsBase", "Test"]
git-tree-sha1 = "36ccc5e09dbba9aea61d78cd7bc46c5113e6ad84"
uuid = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
version = "1.2.1"

    [deps.MonteCarloMeasurements.extensions]
    MakieExt = "Makie"

    [deps.MonteCarloMeasurements.weakdeps]
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.MultivariateStats]]
deps = ["Arpack", "Distributions", "LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI", "StatsBase"]
git-tree-sha1 = "816620e3aac93e5b5359e4fdaf23ca4525b00ddf"
uuid = "6f286f6a-111f-5878-ab1e-185364afe411"
version = "0.10.3"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NNlib]]
deps = ["Adapt", "Atomix", "ChainRulesCore", "GPUArraysCore", "KernelAbstractions", "LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "da09a1e112fd75f9af2a5229323f01b56ec96a4c"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.9.24"

    [deps.NNlib.extensions]
    NNlibAMDGPUExt = "AMDGPU"
    NNlibCUDACUDNNExt = ["CUDA", "cuDNN"]
    NNlibCUDAExt = "CUDA"
    NNlibEnzymeCoreExt = "EnzymeCore"
    NNlibFFTWExt = "FFTW"
    NNlibForwardDiffExt = "ForwardDiff"

    [deps.NNlib.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    cuDNN = "02a925ec-e4fe-4b08-9a7e-0d78e3d38ccd"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NamedArrays]]
deps = ["Combinatorics", "DataStructures", "DelimitedFiles", "InvertedIndices", "LinearAlgebra", "Random", "Requires", "SparseArrays", "Statistics"]
git-tree-sha1 = "58e317b3b956b8aaddfd33ff4c3e33199cd8efce"
uuid = "86f7a689-2022-50b4-a561-43c23ac3c673"
version = "0.10.3"

[[deps.NamedTupleTools]]
git-tree-sha1 = "90914795fc59df44120fe3fff6742bb0d7adb1d0"
uuid = "d9ec5142-1e00-5aa0-9d6a-321866360f50"
version = "0.14.3"

[[deps.NaturalSort]]
git-tree-sha1 = "eda490d06b9f7c00752ee81cfa451efe55521e21"
uuid = "c020b1a1-e9b0-503a-9c33-f039bfc54a85"
version = "1.0.0"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "3cebfc94a0754cc329ebc3bab1e6c89621e791ad"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.20"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.OffsetArrays]]
git-tree-sha1 = "1a27764e945a152f7ca7efa04de513d473e9542e"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.14.1"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+2"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7493f61f55a6cce7325f197443aa80d32554ba10"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.15+1"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "d9b79c4eed437421ac4285148fcadf42e0700e89"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.9.4"

    [deps.Optim.extensions]
    OptimMOIExt = "MathOptInterface"

    [deps.Optim.weakdeps]
    MathOptInterface = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"

[[deps.Optimisers]]
deps = ["ChainRulesCore", "Functors", "LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "6572fe0c5b74431aaeb0b18a4aa5ef03c84678be"
uuid = "3bd65402-5787-11e9-1adc-39752487f4e2"
version = "0.3.3"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6703a85cb3781bd5909d48730a67205f3f31a575"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.3+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "dfdf5519f235516220579f949664f1bf44e741c5"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.3"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.42.0+1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "949347156c25054de2db3b166c52ac4728cbad65"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.31"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e127b609fb9ecba6f201ba7ab753d5a605d53801"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.54.1+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.ParetoSmoothedImportanceSampling]]
deps = ["CSV", "DataFrames", "Distributions", "JSON", "Printf", "Random", "Statistics", "StatsFuns", "Test"]
git-tree-sha1 = "c678e21715f9b6bbf4cc63047f935a68a9b44f20"
uuid = "98f080ec-61e2-11eb-1c7b-31ea1097256f"
version = "1.5.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "35621f10a7531bc8fa58f74610b1bfb70a3cfc6b"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.43.4+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "6e55c6841ce3411ccb3457ee52fc48cb698d6fb0"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.2.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "7b1a9df27f072ac4c9c7cbe5efb198489258d1f5"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.1"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "TOML", "UUIDs", "UnicodeFun", "UnitfulLatexify", "Unzip"]
git-tree-sha1 = "45470145863035bb124ca51b320ed35d071cc6c2"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.40.8"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "5152abbdab6488d5eec6a01029ca6697dff4ec8f"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.23"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "8f6bc219586aef8baf0ff9a5fe16ee9c70cb65e4"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.2"

[[deps.PtrArrays]]
git-tree-sha1 = "77a42d78b6a92df47ab37e177b2deac405e1c88f"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.2.1"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "492601870742dcd38f233b23c3ec629628c1d724"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.7.1+1"

[[deps.Qt6Declarative_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6ShaderTools_jll"]
git-tree-sha1 = "e5dd466bf2569fe08c91a2cc29c1003f4797ac3b"
uuid = "629bc702-f1f5-5709-abd5-49b8460ea067"
version = "6.7.1+2"

[[deps.Qt6ShaderTools_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll"]
git-tree-sha1 = "1a180aeced866700d4bebc3120ea1451201f16bc"
uuid = "ce943373-25bb-56aa-8eca-768745ed7b5a"
version = "6.7.1+1"

[[deps.Qt6Wayland_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Qt6Base_jll", "Qt6Declarative_jll"]
git-tree-sha1 = "729927532d48cf79f49070341e1d918a65aba6b0"
uuid = "e99dba38-086e-5de3-a5b1-6e4c66e897c3"
version = "6.7.1+1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "cda3b045cf9ef07a08ad46731f5a3165e56cf3da"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.1"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Random123]]
deps = ["Random", "RandomNumbers"]
git-tree-sha1 = "4743b43e5a9c4a2ede372de7061eed81795b12e7"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.7.0"

[[deps.RandomNumbers]]
deps = ["Random"]
git-tree-sha1 = "c6ec94d2aaba1ab2ff983052cf6a606ca5985902"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.6.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.RecursiveArrayTools]]
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "b034171b93aebc81b3e1890a036d13a9c4a9e3e0"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "3.27.0"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsFastBroadcastExt = "FastBroadcast"
    RecursiveArrayToolsForwardDiffExt = "ForwardDiff"
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsReverseDiffExt = ["ReverseDiff", "Zygote"]
    RecursiveArrayToolsSparseArraysExt = ["SparseArrays"]
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    FastBroadcast = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "ffdaf70d81cf6ff22c2b6e733c900c3321cab864"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.1"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "852bd0f55565a9e973fcfee83a84413270224dc4"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.8.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58cdd8fb2201a6267e1db87ff148dd6c1dbd8ad8"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.1+0"

[[deps.Roots]]
deps = ["Accessors", "CommonSolve", "Printf"]
git-tree-sha1 = "3a7c7e5c3f015415637f5debdf8a674aa2c979c4"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "2.2.1"

    [deps.Roots.extensions]
    RootsChainRulesCoreExt = "ChainRulesCore"
    RootsForwardDiffExt = "ForwardDiff"
    RootsIntervalRootFindingExt = "IntervalRootFinding"
    RootsSymPyExt = "SymPy"
    RootsSymPyPythonCallExt = "SymPyPythonCall"

    [deps.Roots.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalRootFinding = "d2bf35a9-74e0-55ec-b149-d360ff49b807"
    SymPy = "24249f21-da20-56a4-8eb1-6a02cf4ae2e6"
    SymPyPythonCall = "bc8888f7-b21e-4b7c-a06a-5d9c9496438c"

[[deps.RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "04c968137612c4a5629fa531334bb81ad5680f00"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.13"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[deps.SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "456f610ca2fbd1c14f5fcf31c6bfadc55e7d66e0"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.43"

[[deps.SciMLBase]]
deps = ["ADTypes", "Accessors", "ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "Expronicon", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "PrecompileTools", "Preferences", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "SciMLStructures", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "ce6fb9b0d756446d902e4495f2447fa2ebfbb1f4"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "2.54.2"

    [deps.SciMLBase.extensions]
    SciMLBaseChainRulesCoreExt = "ChainRulesCore"
    SciMLBaseMakieExt = "Makie"
    SciMLBasePartialFunctionsExt = "PartialFunctions"
    SciMLBasePyCallExt = "PyCall"
    SciMLBasePythonCallExt = "PythonCall"
    SciMLBaseRCallExt = "RCall"
    SciMLBaseZygoteExt = "Zygote"

    [deps.SciMLBase.weakdeps]
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    PartialFunctions = "570af359-4316-4cb7-8c74-252c00c2016b"
    PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    RCall = "6f49c342-dc21-5d91-9882-a32aef131414"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.SciMLOperators]]
deps = ["Accessors", "ArrayInterface", "DocStringExtensions", "LinearAlgebra", "MacroTools"]
git-tree-sha1 = "e39c5f217f9aca640c8e27ab21acf557a3967db5"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "0.3.10"
weakdeps = ["SparseArrays", "StaticArraysCore"]

    [deps.SciMLOperators.extensions]
    SciMLOperatorsSparseArraysExt = "SparseArrays"
    SciMLOperatorsStaticArraysCoreExt = "StaticArraysCore"

[[deps.SciMLStructures]]
deps = ["ArrayInterface"]
git-tree-sha1 = "25514a6f200219cd1073e4ff23a6324e4a7efe64"
uuid = "53ae85a6-f571-4167-b2af-e1d143709226"
version = "1.5.0"

[[deps.ScientificTypesBase]]
git-tree-sha1 = "a8e18eb383b5ecf1b5e6fc237eb39255044fd92b"
uuid = "30f210dd-8aff-4c5f-94ba-8e64358c1161"
version = "3.0.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "ff11acffdb082493657550959d4feb4b6149e73a"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.5"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleUnPack]]
git-tree-sha1 = "58e6353e72cde29b90a69527e56df1b5c3d8c437"
uuid = "ce78b400-467f-4804-87d8-8f486da07d0a"
version = "1.1.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SparseInverseSubset]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "52962839426b75b3021296f7df242e40ecfc0852"
uuid = "dc90abb0-5640-4711-901d-7e5b23a2fada"
version = "0.1.2"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "2f5d4697f21388cbe1ff299430dd169ef97d7e14"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.4.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

[[deps.Static]]
deps = ["CommonWorldInvalidations", "IfElse", "PrecompileTools"]
git-tree-sha1 = "87d51a3ee9a4b0d2fe054bdd3fc2436258db2603"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.1.1"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "Static"]
git-tree-sha1 = "96381d50f1ce85f2663584c8e886a6ca97e60554"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.8.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "eeafab08ae20c62c44c8399ccb9354a04b80db50"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.7"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.StatisticalRethinking]]
deps = ["CSV", "DataFrames", "Dates", "Distributions", "DocStringExtensions", "Documenter", "KernelDensity", "LinearAlgebra", "MCMCChains", "MonteCarloMeasurements", "NamedArrays", "NamedTupleTools", "Optim", "OrderedCollections", "Parameters", "ParetoSmoothedImportanceSampling", "PrettyTables", "Random", "Reexport", "Requires", "Statistics", "StatsBase", "StatsFuns", "StructuralCausalModels", "Tables", "Test", "Unicode"]
git-tree-sha1 = "93b986000a0e538bd68a01d121a49ad2128545eb"
uuid = "2d09df54-9d0f-5258-8220-54c2a3d4fbee"
version = "4.8.1"

[[deps.StatisticalRethinkingPlots]]
deps = ["Distributions", "DocStringExtensions", "KernelDensity", "LaTeXStrings", "Parameters", "Plots", "Reexport", "Requires", "StatisticalRethinking", "StatsPlots"]
git-tree-sha1 = "bd7bd318815654491e6350c662020119be7792a0"
uuid = "e1a513d0-d9d9-49ff-a6dd-9d2e9db473da"
version = "1.1.0"

[[deps.StatisticalTraits]]
deps = ["ScientificTypesBase"]
git-tree-sha1 = "542d979f6e756f13f862aa00b224f04f9e445f11"
uuid = "64bff920-2084-43da-a3e6-9bb72801c0c9"
version = "3.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "5cf7606d6cef84b543b483848d4ae08ad9832b21"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.3"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "b423576adc27097764a90e163157bcfc9acf0f46"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.2"
weakdeps = ["ChainRulesCore", "InverseFunctions"]

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

[[deps.StatsPlots]]
deps = ["AbstractFFTs", "Clustering", "DataStructures", "Distributions", "Interpolations", "KernelDensity", "LinearAlgebra", "MultivariateStats", "NaNMath", "Observables", "Plots", "RecipesBase", "RecipesPipeline", "Reexport", "StatsBase", "TableOperations", "Tables", "Widgets"]
git-tree-sha1 = "3b1dcbf62e469a67f6733ae493401e53d92ff543"
uuid = "f3b207a7-027a-5e70-b257-86293d7955fd"
version = "0.15.7"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a6b1675a536c5ad1a60e5a5153e1fee12eb146e3"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.0"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "f4dc295e983502292c4c3f951dbb4e985e35b3be"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.18"
weakdeps = ["Adapt", "GPUArraysCore", "SparseArrays", "StaticArrays"]

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = "GPUArraysCore"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

[[deps.StructuralCausalModels]]
deps = ["CSV", "Combinatorics", "DataFrames", "DataStructures", "Distributions", "DocStringExtensions", "LinearAlgebra", "NamedArrays", "Reexport", "Statistics"]
git-tree-sha1 = "d7531b8dbacf19be09e36df85619556b05ceb1e5"
uuid = "a41e6734-49ce-4065-8b83-aff084c01dfd"
version = "1.4.2"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "0225f7c62f5f78db35aae6abb2e5cabe38ce578f"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.31"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableOperations]]
deps = ["SentinelArrays", "Tables", "Test"]
git-tree-sha1 = "e383c87cf2a1dc41fa30c093b2a19877c83e1bc1"
uuid = "ab02a1b2-a7df-11e8-156e-fb1833f50b87"
version = "1.2.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.TerminalLoggers]]
deps = ["LeftChildRightSiblingTrees", "Logging", "Markdown", "Printf", "ProgressLogging", "UUIDs"]
git-tree-sha1 = "f133fab380933d042f6796eda4e130272ba520ca"
uuid = "5d786b92-1e48-4d6f-9151-6b4477ca9bed"
version = "0.1.7"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.Tracker]]
deps = ["Adapt", "ChainRulesCore", "DiffRules", "ForwardDiff", "Functors", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NNlib", "NaNMath", "Optimisers", "Printf", "Random", "Requires", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "da45269e1da051c2a13624194fcdc74d6483fad5"
uuid = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
version = "0.2.35"
weakdeps = ["PDMats"]

    [deps.Tracker.extensions]
    TrackerPDMatsExt = "PDMats"

[[deps.TranscodingStreams]]
git-tree-sha1 = "e84b3a11b9bece70d14cce63406bbc79ed3464d2"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.2"

[[deps.Transducers]]
deps = ["Adapt", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "ConstructionBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "Requires", "Setfield", "SplittablesBase", "Tables"]
git-tree-sha1 = "3064e780dbb8a9296ebb3af8f440f787bb5332af"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.80"

    [deps.Transducers.extensions]
    TransducersBlockArraysExt = "BlockArrays"
    TransducersDataFramesExt = "DataFrames"
    TransducersLazyArraysExt = "LazyArrays"
    TransducersOnlineStatsBaseExt = "OnlineStatsBase"
    TransducersReferenceablesExt = "Referenceables"

    [deps.Transducers.weakdeps]
    BlockArrays = "8e7c35d0-a365-5155-bbbb-fb81a777f24e"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    OnlineStatsBase = "925886fa-5bf2-5e8e-b522-a9147a512338"
    Referenceables = "42d2dcc6-99eb-4e98-b66c-637b7d73030e"

[[deps.Tricks]]
git-tree-sha1 = "7822b97e99a1672bfb1b49b668a6d46d58d8cbcb"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.9"

[[deps.Turing]]
deps = ["ADTypes", "AbstractMCMC", "AdvancedHMC", "AdvancedMH", "AdvancedPS", "AdvancedVI", "BangBang", "Bijectors", "DataStructures", "Distributions", "DistributionsAD", "DocStringExtensions", "DynamicPPL", "EllipticalSliceSampling", "ForwardDiff", "Libtask", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "MCMCChains", "NamedArrays", "Printf", "Random", "Reexport", "Requires", "SciMLBase", "Setfield", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "4170ff68a0aa2b26b3944ba7bd8789a46d34e6bc"
uuid = "fce5fe82-541a-59a6-adf8-730c64b5f9a0"
version = "0.30.9"

    [deps.Turing.extensions]
    TuringDynamicHMCExt = "DynamicHMC"
    TuringOptimExt = "Optim"

    [deps.Turing.weakdeps]
    DynamicHMC = "bbc10e6e-7c05-544b-b16e-64fede858acb"
    Optim = "429524aa-4258-5aef-a3af-852621145aeb"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "d95fe458f26209c66a187b1114df96fd70839efd"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.21.0"
weakdeps = ["ConstructionBase", "InverseFunctions"]

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "975c354fcd5f7e1ddcc1f1a23e6e091d99e99bc8"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.6.4"

[[deps.UnsafeAtomics]]
git-tree-sha1 = "6331ac3440856ea1988316b46045303bef658278"
uuid = "013be700-e6cd-48c3-b4a1-df204f14c38f"
version = "0.2.1"

[[deps.UnsafeAtomicsLLVM]]
deps = ["LLVM", "UnsafeAtomics"]
git-tree-sha1 = "2d17fabcd17e67d7625ce9c531fb9f40b7c42ce4"
uuid = "d80eeb9a-aca5-4d75-85e5-170c8b632249"
version = "0.2.1"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.VectorizationBase]]
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "e7f5b81c65eb858bed630fe006837b935518aca5"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.70"

[[deps.Vulkan_Loader_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Wayland_jll", "Xorg_libX11_jll", "Xorg_libXrandr_jll", "xkbcommon_jll"]
git-tree-sha1 = "2f0486047a07670caad3a81a075d2e518acc5c59"
uuid = "a44049a8-05dd-5a78-86c9-5fde0876e88c"
version = "1.3.243+0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "EpollShim_jll", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "7558e29847e99bc3f04d6569e82d0f5c54460703"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+1"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "93f43ab61b16ddfb2fd3bb13b3ce241cafb0e6c9"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.31.0+0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.Widgets]]
deps = ["Colors", "Dates", "Observables", "OrderedCollections"]
git-tree-sha1 = "fcdae142c1cfc7d89de2d11e08721d0f2f86c98a"
uuid = "cc8bc4a8-27d6-5769-a93b-9d913e69aa62"
version = "0.6.6"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "1165b0443d0eca63ac1e32b8c0eb69ed2f4f8127"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "a54ee957f4c86b526460a720dbc882fa5edcbefc"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.41+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ac88fb95ae6447c8dda6a5503f3bafd496ae8632"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.4.6+0"

[[deps.Xorg_libICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "326b4fea307b0b39892b3e85fa451692eda8d46c"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.1.1+0"

[[deps.Xorg_libSM_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libICE_jll"]
git-tree-sha1 = "3796722887072218eabafb494a13c963209754ce"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.4+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "afead5aba5aa507ad5a3bf01f58f82c8d1403495"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6035850dcc70518ca32f012e46015b9beeda49d8"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.11+0"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "34d526d318358a859d7de23da945578e8e8727b7"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.4+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "d2d1a5c49fae4ba39983f63de6afcbea47194e85"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.6+0"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "47e45cd78224c53109495b3e324df0c37bb61fbe"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.11+0"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8fdda4c692503d44d04a0603d9ac0982054635f9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.1+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "bcd466676fef0878338c61e655629fa7bbc69d8e"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.0+0"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "730eeca102434283c50ccf7d1ecdadf521a765a4"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.2+0"

[[deps.Xorg_xcb_util_cursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_jll", "Xorg_xcb_util_renderutil_jll"]
git-tree-sha1 = "04341cb870f29dcd5e39055f895c39d016e18ccd"
uuid = "e920d4aa-a673-5f3a-b3d7-f755a4d47c43"
version = "0.1.4+0"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "330f955bc41bb8f5270a369c473fc4a5a4e4d3cb"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.6+0"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "691634e5453ad362044e2ad653e79f3ee3bb98c3"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.39.0+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e92a1a012a10506618f10b7047e478403a046c77"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "555d1076590a6cc2fdee2ef1469451f872d8b41b"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.6+1"

[[deps.ZygoteRules]]
deps = ["ChainRulesCore", "MacroTools"]
git-tree-sha1 = "27798139afc0a2afa7b1824c206d5e87ea587a00"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.5"

[[deps.eudev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "gperf_jll"]
git-tree-sha1 = "431b678a28ebb559d224c0b6b6d01afce87c51ba"
uuid = "35ca27e7-8b34-5b7f-bca9-bdc33f59eb06"
version = "3.2.9+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "936081b536ae4aa65415d869287d43ef3cb576b2"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.53.0+0"

[[deps.gperf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3516a5630f741c9eecb3720b1ec9d8edc3ecc033"
uuid = "1a1c6b14-54f6-533d-8383-74cd7377aa70"
version = "3.1.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1827acba325fdcdf1d2647fc8d5301dd9ba43a9d"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.9.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e17c115d55c5fbb7e52ebedb427a0dca79d4484e"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.2+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libdecor_jll]]
deps = ["Artifacts", "Dbus_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pango_jll", "Wayland_jll", "xkbcommon_jll"]
git-tree-sha1 = "9bf7903af251d2050b467f76bdbe57ce541f7f4f"
uuid = "1183f4f0-6f2a-5f1a-908b-139f9cdfea6f"
version = "0.2.2+0"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "141fe65dc3efabb0b1d5ba74e91f6ad26f84cc22"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "8a22cf860a7d27e4f3498a0fe0811a7957badb38"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.3+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "ad50e5b90f222cfe78aa3d5183a20a12de1322ce"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.18.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "b70c870239dc3d7bc094eb2d6be9b73d27bef280"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.44+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "490376214c4721cdaca654041f635213c6165cb3"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+2"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "814e154bdb7be91d78b6802843f76b6ece642f11"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.6+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d0ea0f4895ef2f5cb83645fa689e52cb55cf493"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2021.12.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9c304562909ab2bab0262639bd4f444d7bc2be37"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+1"
"""

# ╔═╡ Cell order:
# ╠═b7be9915-1237-4aa1-b7e5-493b704ccb79
# ╠═717da12e-ac23-4585-9661-e9f4fd7447fd
# ╠═95965ab2-f250-479f-9d5d-e478dba1fe35
# ╠═ff03fed8-50f9-4b13-95ee-5ff0c596f87e
# ╠═d577b8c8-3670-497a-a6fe-41208a8e8501
# ╠═90028541-7308-476f-b51b-850cd6ad39c4
# ╠═1217e4ab-8e97-4b73-9493-a58c7d8165fe
# ╠═100c3470-b7e4-4890-9347-851b78f5202f
# ╟─464ddfd5-d06b-4615-bd23-e63e03a29f1e
# ╠═fe81bd6a-c7bf-437d-8ca6-f21f9b45b41f
# ╠═b6c8f7af-8e39-4792-a62c-88a41876345d
# ╠═8ee2eec3-3214-48d1-8604-a54ba1a67baf
# ╠═aab03d9d-7ae3-4d80-9e25-75e047dbdce1
# ╠═be9eae13-c04e-492f-9b74-a68b769c7628
# ╠═c64bc09c-0c4b-429d-a91c-fc9915d0dbfa
# ╠═c79ba67c-0694-445f-b320-30cdb88190be
# ╠═573253a5-10d4-458e-9451-89c763658810
# ╠═fa9dff6f-3182-4093-bbfd-8deea404eab0
# ╠═2367f3cf-c568-4f6c-82c6-b7ae42408404
# ╠═8185285a-1640-45e9-8c80-b17b6c960804
# ╠═40634f53-8104-4791-877c-2d498cab9570
# ╠═885a0261-3541-4389-beb7-231c77e2dfcc
# ╠═6837fff8-0c29-4ba1-9b3b-b21c23d861eb
# ╠═1f30d601-4e00-44dd-a6ab-363c431ca875
# ╠═de06a783-c2ff-4f45-8a1e-02977ad31e26
# ╠═30be727e-86e6-41cf-be58-e0b1ffb372c2
# ╠═5ca07e4a-bf45-4e3c-9a5b-3b9b7af38020
# ╠═f95ec79a-0263-46e4-b82e-a274cb7ee7fb
# ╟─81f57cdb-36f8-43bb-86a5-19bac5cd88b1
# ╠═78fe51f6-beea-4155-905d-2d5e6e7d66d7
# ╠═4ea3a429-e457-48a1-a66a-ea66ff21d22c
# ╠═8bb5afba-3f59-4776-9a7b-8df9fed58a90
# ╠═5188efaa-8a5e-4fac-9e7f-bf048079ab9c
# ╠═23810d4f-1dd6-4c16-bf71-231b8b4b726d
# ╠═91780708-0829-4beb-8144-7fc5b7e76b3f
# ╠═cdeba577-a184-4bb5-97a9-6acf3ff516a3
# ╠═e049f64c-02e0-4087-b341-eaf437c5ba49
# ╠═687aec56-682c-4153-ac35-58926c03ea26
# ╠═0c918f86-e896-4b19-8cf8-a77203c3a61b
# ╠═fee0f70c-9aa5-4b60-a285-6923fedbd06c
# ╠═57050894-2fcb-48e0-bd41-14502da1b5ae
# ╠═d31c38f1-94b9-468c-9bce-0469d933c48f
# ╠═aab44993-2275-40dd-8d91-2efb1008ce77
# ╠═2a1dd0cf-5a09-43bd-b7bf-5c93bea3bf3b
# ╠═d15e5041-6021-483e-b059-7170077c2ea6
# ╟─425eea72-221d-4990-90f2-a6654f4e98e1
# ╠═ccc7d18c-08ed-41a7-a556-26030a19d6c5
# ╠═6b73a8a5-c542-4a10-8cf1-0a7e40c3cc98
# ╠═bc41a9ab-c960-4d17-9782-f01721337aea
# ╠═40ec9daa-913e-4b2c-a0aa-3e70a2de7c71
# ╠═b938e63c-29b1-4e49-90af-f9b2ab2e5bdd
# ╠═7e316c72-496e-4758-bb78-f22cefa9fb6c
# ╠═e5428608-cfc2-4fb0-873d-9a4944fb27f6
# ╟─0d6baf1d-2e2a-4742-944a-072bbd24b628
# ╠═ef730308-7bf8-489a-9ab5-a869efe6083a
# ╠═1c4b4cb8-12c0-4fb3-8523-062c7028f746
# ╠═9610477f-8311-4cbf-8544-b9f4836926d6
# ╠═e5216885-c156-4454-ac96-eed454435695
# ╠═6e47526a-310a-4a3e-aab5-0fe71c6c7814
# ╠═944c59b8-ecf6-4ec3-9e81-7ffb8692db36
# ╠═233cd90e-463d-49fb-9a54-34e2750c2a8c
# ╠═b28587b9-5e60-42b0-9874-d47b3e03b97c
# ╠═4fb1f19d-2802-4a0f-bb35-1e21c0be68f3
# ╠═aad09fb4-1fee-454f-bdad-65b2a93255ca
# ╠═0d451930-833e-4050-b2f9-d5f997fb0098
# ╠═3878adef-0d96-4e73-ab37-4e761e01e0ac
# ╠═500fb09f-f952-46a0-8d63-98279e630882
# ╠═95d072b9-5940-49ce-97a8-8dde13c25939
# ╠═1f3d5631-8261-4c3b-8e34-761d23eb5e2e
# ╠═a856d989-5fb6-4148-ac7d-2ce52952c1a3
# ╠═9a7ebb96-5ce1-4093-8c85-9522edebab0e
# ╠═48d158ed-a25f-4ebe-8863-6c92071c251c
# ╠═199ae6d5-7306-4802-bd18-4232fdb98f5f
# ╠═aee19854-5c3d-4a9e-8639-91843800d1b6
# ╠═762055f6-c26a-4b7b-b45b-83cacff6c779
# ╠═dba906be-9d58-471f-bbd7-4318b580ed37
# ╠═e01fa7a9-16ac-498e-97d3-8c9fe1255f43
# ╟─48fe8dff-dc91-4996-bfe7-911d2a09b4c8
# ╠═aef2347f-dea0-4bbb-864c-c7d0d09814c6
# ╠═011c2852-91b3-4745-b453-e0ffcdba7f23
# ╠═6916ba32-8ebc-4aa7-adf7-f6717fde60e2
# ╠═afaf9be1-a557-4b73-9279-f9cf12525958
# ╠═707fc9b1-ae51-48be-bf77-a031f7d82489
# ╠═1c03fd5e-0c6a-4118-b11a-0f4d2392f923
# ╠═1cd43a15-d361-4e4a-84e2-f1464659a654
# ╠═2be10e8e-9a44-4b0b-bd81-7e4cdc999afc
# ╠═ee84ac32-58f1-49bc-b705-fbc709e0f11a
# ╠═8448e4cd-0bce-4426-85db-72a40a279b1d
# ╠═640ac000-dd55-4dda-846f-303404360ab5
# ╠═038bc011-279e-492a-bbfc-074630cdff3e
# ╠═c8d7399e-ad0d-4835-8fa0-1c8ad66e7d34
# ╠═1512c0e0-bee0-4fce-9062-39c60e43f3f8
# ╠═93a5e590-0ab0-4a13-8944-226258424f7d
# ╠═aba1a47c-534b-4ce0-b41f-d68c3331207d
# ╠═2ff1b0f7-4a07-467f-bf0d-069c5b766ed1
# ╠═0f77c94d-011e-4a55-99a1-0ee67acf63fb
# ╠═f9419d58-0770-4715-840d-49b7f7237ba9
# ╠═75a8aad7-3460-42bb-a335-a4ca6e6f0435
# ╠═765f999b-20f2-440f-87ff-d01ef82cefc7
# ╠═c12592b9-3c10-4c90-93bc-7f5289f9b90f
# ╠═823ad4ee-f4fa-44a8-b3df-2f1704bea9f2
# ╠═9cd414f2-14ab-4a17-822e-321c8e64a9d3
# ╠═7d6ab552-9096-46cd-9091-ab10ea498ec5
# ╠═3aa50cb9-7f79-4c85-b025-dfae05b2a364
# ╠═91b628c8-884e-43ad-808c-17bdec8be4a0
# ╠═740e3801-e3b9-4d61-b205-540cfd837446
# ╠═d847eb65-1a0f-4dd4-a87a-b2d2b670ccb6
# ╠═4cc25feb-2757-4b8f-8b00-f7fb6203507b
# ╠═54b6c38e-e053-40c4-8d96-5528888e7ac8
# ╠═15140a50-7fd3-4138-a5c4-f2e81f036af9
# ╠═f2f97686-af08-48a9-a125-e2da8ac13e18
# ╠═14d862c0-ddb1-4dff-a315-888b076f2f1e
# ╠═bd2a7422-e240-466f-9454-60fa17607ed6
# ╠═42587c2d-785f-4221-906f-b481d3f4b539
# ╠═0d803f54-e82f-4ee7-9b31-f5f0d679ff69
# ╠═672df617-394c-48ea-b117-f3fb19c20e13
# ╠═cf339bbf-34ac-40c4-9847-5a3118d7775e
# ╠═1ac33e8a-dd1d-4e79-82ce-efe237bace3e
# ╠═1b5df6ed-d6fa-4db7-ad3a-51c1af13a7fc
# ╠═a37d8a3b-1be7-4322-aeb3-e96785ce38d5
# ╠═94af3ac3-e468-4aee-b5e9-d0bae5c4fa41
# ╠═ace362ef-5676-40af-9b6c-7fda702bb5b8
# ╠═6ad5c52a-eb44-49bf-9796-c89640d9882d
# ╠═0a735ed0-16ab-42a1-b8d6-e21c4cc010b3
# ╠═abdbfd66-c74b-48bc-9c33-c0c9c4c522ae
# ╠═8979364d-dcdc-4ef6-bec3-04b8c9036347
# ╠═744877ee-e7ec-4d77-883b-1437578b0e62
# ╠═f1d976dc-9a74-4a84-be45-f25d193a6f43
# ╠═862a30ad-c28c-4145-9ac1-59c09ba08cab
# ╠═9468f5d9-3eb0-4cd6-a40b-2401712991cc
# ╠═a591c017-bffd-49d8-aa3d-c7c1b40100fd
# ╠═8fa9f394-bae7-4cd1-91dc-1e444bd296c3
# ╠═0b2ace5b-2e9a-4455-8068-9207dcc2f8f3
# ╠═3098cdb9-4802-466c-a09c-f106dd4b50fb
# ╠═7452a574-2021-45b4-b907-fdc39bffe9b3
# ╠═af4eeae4-1d1b-460c-93b8-1e9ac23e9d60
# ╠═afa9b842-ca47-48bb-bd2f-65f9bf3f2ac6
# ╠═ed4327aa-160f-4b64-9548-cb0422890a2e
# ╠═7e40e00a-4b2f-4f9e-82f0-847e17e2423c
# ╠═6c699793-ed34-400f-b4de-31ccef89cb60
# ╠═df368764-5237-4cbb-80c8-eac7c13844da
# ╠═e19912ef-e590-4caa-ae78-6fd35c6bee56
# ╠═0bbb0ce8-01bd-4dfd-ac9d-060d1a00d6fb
# ╠═6c61f30f-0227-4551-85ee-2a7dcea84558
# ╠═89d2c59f-be30-422b-bdd9-df7a125b949b
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
