### A Pluto.jl notebook ###
# v0.19.41

using Markdown
using InteractiveUtils

# ╔═╡ be482a65-b8f9-48b3-aba8-ff2572e3c7ca
begin
  using Pkg, DrWatson
  using PlutoUI
  TableOfContents()
end

# ╔═╡ ffd99df2-d429-4355-ae71-cfc2906f72d3
begin
	using Optim
	using Turing
	using DataFrames
	using CSV
	using Random
	using Distributions
	using StatisticalRethinking
	using StatisticalRethinking: link
	using StatisticalRethinkingPlots
	using ParetoSmooth
	using StatsPlots
	using Plots.PlotMeasures
	using StatsBase
	using FreqTables
	using Logging
end

# ╔═╡ 90756137-094d-4a22-93a1-a2efdfe8beae
md"# Chap 13 Models With Memory (Multilevel)"

# ╔═╡ c64dc097-1d61-45db-94ce-2cb4456cbdb7
versioninfo()

# ╔═╡ 57ed207c-b572-4688-b2ef-1e3c574fcea0
html"""
<style>
	main {
		margin: 0 auto;
		max-width: 2000px;
    	padding-left: max(30px, 5%);
    	padding-right: max(220px, 10%);
	}
</style>
"""

# ╔═╡ 45d98b5a-d248-41cd-9c5c-e792444dd7d9
begin
	Plots.default(label=false);
	#Logging.disable_logging(Logging.Warn);
end;

# ╔═╡ 8147ea5b-1853-49bb-952d-231bc81928c5
md" # 13.1 Example: multilevel tadpoles"

# ╔═╡ 9941ca6b-98be-4ccd-848d-6bc9e2cfd4a2
md" ## Code 13.1 Load the tadpole data"

# ╔═╡ b1733234-0b5a-4868-913f-082737c16584
begin
	frogs = CSV.read(sr_datadir("reedfrogs.csv"), DataFrame)
	frogs.tank = 1:nrow(frogs)
	describe(frogs)
end

# ╔═╡ f5d40d5c-69cc-4026-b61d-bf7a212638fa
first(frogs, 3)

# ╔═╡ c09d2976-1e1c-44f8-9c4f-4fd7a2ba72b2
no_of_tanks, no_of_cols = size(frogs)

# ╔═╡ ccd5f2ec-077d-44a5-a510-27f77058ce73
levels(frogs.tank)

# ╔═╡ 27cfa500-3ea9-4db9-80dc-7b2d8c158b24
select(frogs, [:density, :surv, :propsurv, :tank])

# ╔═╡ 806b8b3e-ec11-4819-b6d8-c11424e9639a
# a mix of Int and Float, corrplot fails. Strange that AbstractFloat(Vec[Int64]) will fail.
#@df frogs corrplot([:density, :surv, :propsurv, :tank]; seriestype=:scatter, ms=0.2, 
	#alpha=0.5, size=(950, 800), bins=30, grid=true)

# convert dataframe into a matrix of Float.
corrplot(Matrix(select(frogs, [:density, :surv, :propsurv, :tank])); 
	seriestype=:scatter, labels=["density", "no_of_surv", "prop_surv","tank"],
	ms=4, alpha=0.8, size=(950, 800), bins=10, grid=true)

# ╔═╡ 58b836dd-cf22-4d80-a3db-94f2b405874d
md" ## Code 13.2 `m13_1`: intercept for each cluster/tank but variation parameter for all clusters"

# ╔═╡ a4f381c5-cf17-481f-8f42-eb9e41df61a7
@model function m13_1(no_of_surv, no_of_total, tank_vec)
    no_of_tanks = length(levels(tank_vec))
    a ~ filldist(Normal(0, 1.5), no_of_tanks)
    p = logistic.(a)
    @. no_of_surv ~ Binomial(no_of_total, p)
end

# ╔═╡ be6041bc-c7f1-44a8-8ca0-66fd6fdb252a
begin
	Random.seed!(1)
	@time m13_1_ch = sample(m13_1(frogs.surv, frogs.density, frogs.tank), 
		NUTS(200, 0.65, init_ϵ=0.5), 1000)
	m13_1_df = DataFrame(m13_1_ch);
end

# ╔═╡ f0d6194c-8019-45d3-94d0-f7bb8fe0dc9d
#m13_1_df's columns are reshuffled, not from a[1] to a[48].
# so use the original MCMC chain
@time logodds_median_mat = median(reshape(m13_1_ch.value[:, 1:48, 1], 1000, 48), dims=1)

# ╔═╡ 5e535d50-ee08-40b3-8316-136217f96b5f
begin
	#logodds_median_mat = median(Array(m13_1_df), dims=1)
	@show size(logodds_median_mat)
	log_odds_survival = reshape(logodds_median_mat, no_of_tanks)
	histogram(log_odds_survival, bins=10, xlabel="log_odds_survival")
end

# ╔═╡ e92f8963-dfd7-4e66-9091-89dde2d09200
logodds_est_stddev_mat = std(reshape(m13_1_ch.value[:, 1:48, 1], 1000, 48), dims=1)

# ╔═╡ 3fd1d25a-14a4-4e25-a39c-97aa4866711a
std(logodds_median_mat)

# ╔═╡ 6dab7b44-9758-4dec-ae4d-b412769ef44f
begin
	scatter(frogs.propsurv, logistic.(log_odds_survival), alpha=0.6, 
		xlabel="propsurv", ylabel="probability of survival")
	plot!([0.1, 1.0], [0.1, 1.0], alpha=0.4)
end

# ╔═╡ 8597ecfd-039b-4df3-85c9-d7ced79779ea
scatter(frogs.propsurv, log_odds_survival, alpha=0.6, 
	xlabel="propsurv", ylabel="log-odds of survival")

# ╔═╡ 9dbd3e3a-f3d9-4c7b-a1c6-56c9048a31fd
scatter(frogs.density, log_odds_survival, alpha=0.6,
	xlabel="density", ylabel="log-odds of survival")

# ╔═╡ 4471366b-9d99-4d84-b679-a8d8f709089b
scatter(frogs.tank, log_odds_survival, alpha=0.6, 
	xlabel="tank ID", ylabel="log-odds of survival")

# ╔═╡ a1144feb-1264-4429-b019-d2580f1dee8e
md" ## Code 13.3 `m13_2`: multilevel with hyperpriors"

# ╔═╡ 791f6424-bebc-4e58-adfc-c8f1ef87d4a2
md" ## Code 13.4 WAIC compare `m13_1` to `m13_2`"

# ╔═╡ 794e96b7-6a8b-414a-b7f6-0341a9cbfbac
link_fun = (r, dr) -> begin
    a = get(r, "a[$(dr.tank)]", 0)
    p = logistic(a)
    binomlogpdf(dr.density, p, dr.surv)
end

# ╔═╡ 4147ceaf-0a1a-48e4-9d5c-436d1f5ce146
md"
- WAIC = -2 `*` lppd + 2 `*` pWAIC;
- lppd in the DataFrame above (output of compare) is in fact -2 `*` lppd.
- `m13_2` has 21 effective parameters (pWAIC), much less than the actual number of parameters (50).
- Also less than that of `m13_1`."

# ╔═╡ 5a5a9af4-e999-4006-b5fc-7b2ad069a910
parentmodule(compare)

# ╔═╡ 277bef7f-964b-4073-8cbc-e098c5541843
md" ## Code 13.5 Fig 13.1 propsurv vs the estimated probability of survival.
- White dots are estimates.
- Blue dots are propsurv (equivalent to estimate for each tank independently)."

# ╔═╡ 96d787aa-3961-4146-b06c-bfaf1ed573d5
#empirical mean
mean(frogs.propsurv)

# ╔═╡ f75d2093-821b-4d3e-9b94-7ff77240176a
md" ## Code 13.6 Fig 13.2 Sample log-odds survival from the posterior"

# ╔═╡ 85c7d13d-7b34-42d0-a870-be47428c5a15
md" # 13.2 Varying effects and the underfitting/overfitting trade-off."

# ╔═╡ 676f183f-fd44-47ce-a53a-b315dbdff5e1
md" ## Code 13.7 Initial values ā and σ, number of ponds, Ni: number of tadpoles in each pond"

# ╔═╡ e33a498b-395f-4684-ba2c-a39b66b91255
begin
	ā = 1.5
	σ = 1.5
	nponds = 60
	no_of_reps = 15
	# The i-th element of `inner` specifies the number of times that the individual entries of the i-th dimension of A should be repeated. The i-th element of `outer` specifies the number of times that a slice along the i-th dimension of A should be repeated.
	Ni = repeat([5, 10, 25, 35], inner=no_of_reps);
end

# ╔═╡ 32bc923c-fb78-4f47-8e3a-c6efae58163c
@model function m13_2(S, N, tank)
    tank_size = length(levels(tank))
    σ ~ Exponential()
    ā ~ Normal(0, 1.5)
    a ~ filldist(Normal(ā, σ), tank_size)
    p = logistic.(a)
    @. S ~ Binomial(N, p)
end

# ╔═╡ fde815d6-beb9-4114-82a0-01b8d8aadeae
begin
	Random.seed!(1)
	@show @time m13_2_ch = sample(m13_2(frogs.surv, frogs.density, frogs.tank), NUTS(200, 0.65, init_ϵ=0.2), 1000)
	m13_2_df = DataFrame(m13_2_ch);
end

# ╔═╡ 8072e15d-d96f-41d7-864d-3dadd5fc97e8
size(m13_2_df)

# ╔═╡ 0a91f78d-6214-4a51-81fe-2569a647cd7c
m13_2_ch.value

# ╔═╡ 679425de-c4a5-4ba5-93f9-2124700997d4
begin
	#m13_1_df's columns are reshuffled, not from a[1] to a[48].
	# so use the original MCMC chain
	@time logodds_median_m13_2 = median(reshape(m13_2_ch.value[:, 3:3+no_of_tanks-1, 1], 1000, no_of_tanks), dims=1)
	#logodds_median_mat = median(Array(m13_2_df), dims=1)
	@show size(logodds_median_m13_2)
	log_odds_survival_m13_2 = reshape(logodds_median_m13_2, no_of_tanks)
	scatter(frogs.propsurv, logistic.(log_odds_survival_m13_2), alpha=0.6, xlabel="propsurv", ylabel="prob of survival")
	plot!([0.1, 1.0], [0.1, 1.0], alpha=0.4)
end

# ╔═╡ 97119df8-de27-4484-a51e-e70213d4b335
begin
	scatter(log_odds_survival, log_odds_survival_m13_2, xlabel="m13_1", ylabel="m13_2")
	plot!([-2, 3.5], [-2, 3.5], alpha=0.4)
end

# ╔═╡ 43eb9d81-f034-4c2c-bd37-619705342497
let
	m1_ll = link(m13_1_df, link_fun, eachrow(frogs))
	m1_ll = hcat(m1_ll...);
	
	m2_ll = link(m13_2_df, link_fun, eachrow(frogs))
	m2_ll = hcat(m2_ll...);
	
	compare([m1_ll, m2_ll], :waic, mnames=["m13.1", "m13.2"])
end

# ╔═╡ ccec6027-9f9d-44d1-9e91-f5f74a188acb
let
	Random.seed!()
	post = sample(resetrange(m13_2_ch), 10000)
	global post_df = DataFrame(post)
	
	propsurv_est = [
	    logistic(mean(post_df[:,"a[$i]"]))
	    for i ∈ 1:nrow(frogs)
	]
	
	scatter(propsurv_est, mc=:white, xlab="tank", ylab="proportion survival", ylim=(-0.05, 1.05))
	scatter!(frogs.propsurv, mc=:blue, ms=3, alpha=0.6)
	#draw the mean probability of survival line
	hline!([mean(logistic.(post_df.ā))], ls=:dash, c=:black)
	vline!([16.5, 32.5], c=:black)
	annotate!([
	        (8, 0, ("small tanks", 10)),
	        (16+8, 0, ("medium tanks", 10)),
	        (32+8, 0, ("large tanks", 10))
	    ])
end

# ╔═╡ 4ddcfcb2-64bb-4415-b2a3-8bcb4f39acea
#mean of estimates of prob of survival
mean(logistic.(post_df.ā))

# ╔═╡ c96fc5cc-5b3e-4032-9c7e-b43f486242e6
let
	p1 = plot(xlim=(-3, 4), xlab="log-odds survive", ylab="Density")
	
	for r ∈ first(eachrow(post_df), 100)
	    plot!(Normal(r.ā, r.σ), c=:black, alpha=0.2)
	end
	
	sim_log_odds = @. rand(Normal(post_df.ā[1:8000], post_df.σ[1:8000]));
	@show size(sim_log_odds)
	@show first(sim_log_odds,3)
	p2 = plot(xlab="probability survive", ylab="Density", xlim=(-0.1, 1.1))
	density!(logistic.(sim_log_odds), lw=2)
	
	plot(p1, p2, size=(800, 400), margin=2mm)
end

# ╔═╡ 1b684dbb-17f9-441f-b54e-371d0bf4af5e
md" ## Code 13.8-13.10 Simulate data with a known odds-ratio for each pond"

# ╔═╡ 6ecb0714-28f3-42ac-a2c3-8a3506f801e6
let
	Random.seed!(5005)
	a_pond = rand(Normal(ā, σ), nponds);
	global dsim = DataFrame(pond=1:nponds, Ni=Ni, true_a=a_pond);
	
	# Doesn't make much sense in Julia, but anyways
	
	@show typeof(1:3), typeof([1,2,3])
	
	Random.seed!(1)
	dsim.Si = @. rand(Binomial(dsim.Ni, logistic(dsim.true_a)))
	dsim.p_nopool = dsim.Si ./ dsim.Ni;
	describe(dsim)
end

# ╔═╡ 7ef78fb9-040a-4622-90e0-a173a6721b26
md" ## Code 13.13 `m13_3` Partial pooling: Varying effect model"

# ╔═╡ d3660350-5972-4a04-9991-2afe1d7534c0
@model function m13_3(Si, Ni, pond)
    σ ~ Exponential()
    ā ~ Normal(0, 1.5)
    a_pond ~ filldist(Normal(ā, σ), nponds)
    p = logistic.(a_pond)
    @. Si ~ Binomial(Ni, p)
end

# ╔═╡ 9d1dd75d-68fa-41e8-9a8b-5014a27061a6
begin
	Random.seed!(1)
	@time m13_3_ch = sample(m13_3(dsim.Si, dsim.Ni, dsim.pond), NUTS(), 1000)
	m13_3_df = DataFrame(m13_3_ch);
end

# ╔═╡ beb669bc-d900-4785-89ab-0b1f5f9def46
md" ## Code 13.14 Summarize estimates by `m13_3`"

# ╔═╡ 338e2424-1f47-4232-97d5-f80c72c8f162
describe(m13_3_df)

# ╔═╡ 94cdfc4a-c799-4668-928a-0aa265fb4f53
md" ## Code 13.15 Convert odds-ratio to p"

# ╔═╡ 7c662cb8-ee2f-4dc2-980f-e538635008df
dsim.p_partpool = [
    mean(logistic.(m13_3_df[:,"a_pond[$i]"]))
    for i ∈ 1:nponds
];

# ╔═╡ 91e82d6a-2f2a-4399-97f6-523e17d9ab77
md" ## Code 13.16 True p"

# ╔═╡ bb520798-7ab9-4e52-8f33-aef9219bcae4
dsim.p_true = logistic.(dsim.true_a);

# ╔═╡ 79e07adc-3378-484b-8b65-45275741ca5b
md" ## Code 13.17 - 13.19 estimated p vs true p"

# ╔═╡ d28addae-fc36-4822-9ffc-bb831a0ad03d


# ╔═╡ 89fc29e9-9932-45c9-ba71-ddea749a3eb1
let
	#calculate the error
	dsim.nopool_error = @. abs(dsim.p_nopool - dsim.p_true)
	dsim.partpool_error = @. abs(dsim.p_partpool - dsim.p_true)
	
	gb_pondsize = groupby(dsim, :Ni)
	nopool_avg = combine(gb_pondsize, :nopool_error => mean)
	partpool_avg = combine(gb_pondsize, :partpool_error => mean);
	@show nopool_avg, partpool_avg
	
	vline([15.5, 30.5, 45.5], c=:black)
	annotate!([
	        (8, 0.48, ("tiny ponds(5)", 10)),
	        (23, 0.48, ("small ponds(10)", 10)),
	        (38, 0.48, ("medium ponds(25)", 10)),
	        (53, 0.48, ("large ponds(35)", 10))
	    ])
	
	no_of_reps = 15
	for i in 1:nrow(nopool_avg)
		error_mean = nopool_avg[i,:].nopool_error_mean
		plot!([no_of_reps*(i-1)+1, no_of_reps*i], [error_mean, error_mean], 
			color=:cyan, alpha=0.7, linewidth=1, linestyle=:dash)
	end

	for i in 1:nrow(partpool_avg)
		error_mean = partpool_avg[i,:].partpool_error_mean
		plot!([no_of_reps*(i-1)+1, no_of_reps*i], [error_mean, error_mean], 
			color=:black, alpha=0.7, linewidth=1, linestyle=:solid)
	end
	
	scatter!(dsim.nopool_error, xlab="pond", ylab="absolute error", 
		label="nopool", 
		legend=:topright, color=:cyan, size=(800,500), alpha=0.6, 
		margin=5*Plots.mm)
	scatter!(dsim.partpool_error, mc=:white, alpha=0.6, label="partial pooling")
	ylims!(0,0.6)


end

# ╔═╡ 07e6a510-c868-46c6-8d7e-b764ee4858b6
begin
	histogram(dsim.nopool_error, bins=10, alpha=0.6, 
		label="nopool", legend=:topright)
	histogram!(dsim.partpool_error, bins=10, alpha=0.6, 
		label="partialpool")
end

# ╔═╡ fc227622-466f-4e6f-8b10-c9062915704d
md" ## Code 13.19 - 13.20 Repeat the simulation"

# ╔═╡ 31a10846-a373-4e38-87e8-7bed82ae8707
let
	ā = 1.5
	σ = 1.5
	nponds = 60
	Ni = repeat([5, 10, 25, 35], inner=15)
	a_pond = rand(Normal(ā, σ), nponds)
	
	dsim2 = DataFrame(pond=1:nponds, Ni=Ni, true_a=a_pond)
	dsim2.Si = @. rand(Binomial(dsim2.Ni, logistic(dsim2.true_a)))
	dsim2.p_nopool = dsim2.Si ./ dsim2.Ni
	
	@time m13_3_ch = sample(m13_3(dsim2.Si, dsim2.Ni, dsim2.pond), NUTS(), 1000)
	m13_3_df = DataFrame(m13_3_ch)

	dsim2.p_partpool = [
	    mean(logistic.(m13_3_df[:,"a_pond[$i]"]))
	    for i ∈ 1:nponds
	]
	dsim2.p_true = logistic.(dsim2.true_a)
	dsim2.nopool_error = @. abs(dsim2.p_nopool - dsim2.p_true)
	dsim2.partpool_error = @. abs(dsim2.p_partpool - dsim2.p_true)
	
	gb_pondsize = groupby(dsim2, :Ni)
	nopool_avg = combine(gb_pondsize, :nopool_error => mean)
	partpool_avg = combine(gb_pondsize, :partpool_error => mean);
	@show nopool_avg, partpool_avg
	
	vline([15.5, 30.5, 45.5], c=:black)
	annotate!([
	        (8, 0.48, ("tiny ponds(5)", 10)),
	        (23, 0.48, ("small ponds(10)", 10)),
	        (38, 0.48, ("medium ponds(25)", 10)),
	        (53, 0.48, ("large ponds(35)", 10))
	    ])
	
	no_of_reps = 15

	for i in 1:nrow(nopool_avg)
		error_mean = nopool_avg[i,:].nopool_error_mean
		plot!([no_of_reps*(i-1)+1, no_of_reps*i], [error_mean, error_mean], 
			color=:cyan, alpha=0.7, linewidth=1, linestyle=:dash)
	end

	for i in 1:nrow(partpool_avg)
		error_mean = partpool_avg[i,:].partpool_error_mean
		plot!([no_of_reps*(i-1)+1, no_of_reps*i], [error_mean, error_mean], 
			color=:black, alpha=0.7, linewidth=1, linestyle=:solid)
	end
	
	scatter!(dsim2.nopool_error, xlab="pond", ylab="absolute error", 
		label="nopool", color=:cyan, size=(800,500), alpha=0.7, legend=:topright)
	scatter!(dsim2.partpool_error, mc=:white, alpha=0.7, label="partialpool")
	ylims!(0, 0.6)
end

# ╔═╡ 1f195800-e327-46cf-8bf5-f728756f0132
md" # 13.3 More than one type of cluster."

# ╔═╡ d66a906b-d034-4144-bd4f-d1c3dff7015d
md" ## Code 13.21 `m13_4`: random effect for actor and block"

# ╔═╡ 9293a32f-4296-4f96-88ac-00ac51c23360
begin
	chimpanzees = CSV.read(sr_datadir("chimpanzees.csv"), DataFrame)
	chimpanzees.treatment = 1 .+ chimpanzees.prosoc_left .+ 2*chimpanzees.condition;
end;

# ╔═╡ 04410d55-81c6-4c4d-bef0-5196023b6212
first(chimpanzees,3)

# ╔═╡ 9fa94d73-1100-4d7d-b55e-50c39419b331
size(chimpanzees)

# ╔═╡ 03f31f7c-b6fa-46b3-9785-2b70abbe9dd1
@model function m13_4(pulled_left, actor, block_id, treatment)
    σ_a ~ Exponential()
    σ_g ~ Exponential()
    ā ~ Normal(0, 1.5)
    actors_count = length(levels(actor))
    blocks_count = length(levels(block_id))
    treats_count = length(levels(treatment))
    a ~ filldist(Normal(ā, σ_a), actors_count)
    g ~ filldist(Normal(0, σ_g), blocks_count)
    b ~ filldist(Normal(0, 0.5), treats_count)
    
    p = @. logistic(a[actor] + g[block_id] + b[treatment])
    @. pulled_left ~ Binomial(1, p)
end

# ╔═╡ 012f1b59-ddb2-4906-b5fb-cad11527af97
begin
	Random.seed!(13)
	@time m13_4_ch = sample(m13_4(chimpanzees.pulled_left, chimpanzees.actor, chimpanzees.block, chimpanzees.treatment),
		NUTS(), 4000)
	m13_4_df = DataFrame(m13_4_ch);
end

# ╔═╡ 275aeacc-7e7b-45db-9304-006504302192
m13_4_ch.name_map[:parameters]

# ╔═╡ 3ceb000e-fa81-47aa-b891-47a172d1cab6
axes(m13_4_ch)

# ╔═╡ 5021204a-d75d-4c79-886f-b0b96ad16417
ndims(m13_4_ch)

# ╔═╡ 438cf6c1-1fdc-46cb-a2e3-40e33c20b2f8
plot(m13_4_ch)

# ╔═╡ 3b5a26d5-2d34-45f6-82a8-231e88140ebb
ess_rhat(m13_4_ch)

# ╔═╡ 77023dd9-fde7-4c05-aa03-d206bbbdb500
parentmodule(ess_rhat)

# ╔═╡ 448d4c51-ae2a-4154-9199-756114f6eecf
md" ## Code 13.22 Check the estimate results"

# ╔═╡ c061efe3-bbfe-4736-8f97-091ec5088efc
describe(m13_4_df)

# ╔═╡ be23b9da-4de5-4388-9a64-fedbccaae986
coeftab_plot(m13_4_df, size=(800,600))

# ╔═╡ 4e6264b7-76cf-4593-ae87-50f7a4ca9b6f
md"
- Effect of g/block is very small, close to zero."

# ╔═╡ 678a47cb-6d8b-4994-a713-cc8c274f7411
md" ## Code 13.23 `m13_5`: only one random effect for actor."

# ╔═╡ a621a173-458f-4872-93f7-4e57e19856b9
@model function m13_5(pulled_left, actor, treatment)
    σ_a ~ Exponential()
    ā ~ Normal(0, 1.5)
    actors_count = length(levels(actor))
    treats_count = length(levels(treatment))
    a ~ filldist(Normal(ā, σ_a), actors_count)
    b ~ filldist(Normal(0, 0.5), treats_count)
    
    p = @. logistic(a[actor] + b[treatment])
    @. pulled_left ~ Binomial(1, p)
end

# ╔═╡ 9bef0f5a-28e5-4074-b9d9-f7e52e452fb6
begin
	Random.seed!(14)
	@time m13_5_ch = sample(m13_5(chimpanzees.pulled_left, chimpanzees.actor, chimpanzees.treatment), NUTS(), 4000)
	m13_5_df = DataFrame(m13_5_ch);
end

# ╔═╡ 65beeb3d-d0f4-4931-ac20-b7b22be19eb2
md" ## Code 13.24 WAIC-Compare `m13_4` and `m13_5`"

# ╔═╡ 44783098-f38e-44fe-86e1-946d02f3f9db
m13_4_ll_func = (r, dr) -> begin
    a = get(r, "a[$(dr.actor)]", 0)
    g = get(r, "g[$(dr.block)]", 0)
    b = get(r, "b[$(dr.treatment)]", 0)
    p = logistic(a + g + b)
    binomlogpdf(1, p, dr.pulled_left)
end

# ╔═╡ 73c08bc2-0ebe-4f5a-a769-72d41539a6a0
begin
	m13_4_ll = link(m13_4_df, m13_4_ll_func, eachrow(chimpanzees))
	m13_4_ll = hcat(m13_4_ll...)
end

# ╔═╡ 0e7f2b1b-4ddd-44e9-9c99-4c9e604eb89a
m13_5_ll_func = (r, dr) -> begin
    a = get(r, "a[$(dr.actor)]", 0)
    b = get(r, "b[$(dr.treatment)]", 0)
    p = logistic(a + b)
    binomlogpdf(1, p, dr.pulled_left)
end

# ╔═╡ 3c5564d4-7be2-4028-bb15-ba0313da6782
begin
	m13_5_ll = link(m13_5_df, m13_5_ll_func, eachrow(chimpanzees))
	m13_5_ll = hcat(m13_5_ll...);
end

# ╔═╡ 51067681-8aa3-471d-85df-e78786cec73d
@time compare([m13_4_ll, m13_5_ll], :waic, mnames=["m13_4", "m13_5"])

# ╔═╡ d4cbcaba-14e6-44cc-b667-5d9bd1958b14
parentmodule(compare)

# ╔═╡ 02eeda0b-8d89-44cb-a604-07aa69b010c9
md"
- `m13_4` has 6 more parameters than `m13_5`, but pWAIC(effective number of parameters) is only 2 more."

# ╔═╡ 55780648-3d5e-449b-94cd-312b5d70dad6
md" ## Code 13.25 `m13_6`: random effect for actor, block, and treatment."

# ╔═╡ 73e31e16-bbe9-4c9a-96bb-194c8110deba
@model function m13_6(pulled_left, actor, block_id, treatment)
    σ_a ~ Exponential()
    σ_g ~ Exponential()
    σ_b ~ Exponential()
    ā ~ Normal(0, 1.5)
    actors_count = length(levels(actor))
    blocks_count = length(levels(block_id))
    treats_count = length(levels(treatment))
    a ~ filldist(Normal(ā, σ_a), actors_count)
    g ~ filldist(Normal(0, σ_g), blocks_count)
    b ~ filldist(Normal(0, σ_b), treats_count)
    
    p = @. logistic(a[actor] + g[block_id] + b[treatment])
    @. pulled_left ~ Binomial(1, p)
end

# ╔═╡ c1a1c834-c80e-409c-8cab-b2273021bde7
parentmodule(logistic)

# ╔═╡ b2598a77-4d7b-4878-b555-d1afa47e0eb6
begin
	Random.seed!(15)
	@time m13_6_ch = sample(m13_6(chimpanzees.pulled_left, chimpanzees.actor, chimpanzees.block, chimpanzees.treatment), NUTS(), 4000)
	m13_6_df = DataFrame(m13_6_ch);
end

# ╔═╡ e5df33fd-885f-419f-86ca-de7233b901e4
describe(m13_4_df[:,r"b"])

# ╔═╡ 95164e3b-60db-4e7f-84ed-61d1b2978ff0
describe(m13_6_df[:,r"b"])

# ╔═╡ 97e1d4da-d7ff-43f5-885a-d3e0864bffb1
md"
- Little difference between `m13_4` and `m13_6`.
- $\sigma_b$ of `m13_6` is small, similar to the pre-set value in `m13_4`."

# ╔═╡ a494c2d9-e049-4fbe-aaa6-202810673ace
md" # 13.4 Divergent transitions and non-centered priors."

# ╔═╡ 0eecba9e-0563-4eba-9b2f-679cf1140fb8
md" ## Code 13.26 Devil's Funnel: A model that has many divergent transitions"

# ╔═╡ b1105cc8-bbbc-4aea-ad2f-c12f238e55ac
@model function m13_7(N)
    v ~ Normal(0, 3)
    x ~ Normal(0, exp(v))
end

# ╔═╡ 0e079db5-8e99-4e4b-aa15-0f2dc378fb27
md"**Fit it with only one data point!**"

# ╔═╡ 1acd31f3-b759-454e-aafe-9b36073f5f4f
begin
	Random.seed!(5)
	@time m13_7_ch = sample(m13_7(1), NUTS(), 1000)
end

# ╔═╡ 04ea3d54-2a17-42e1-9365-b304e093fff3
plot(m13_7_ch, margin=5*Plots.mm)

# ╔═╡ 233e1ae8-5d66-4c1f-89d6-528cdb8d2476
ess_rhat(m13_7_ch)

# ╔═╡ a48ce101-c04a-41c2-a2c4-984a16846424
parentmodule(ess_rhat)

# ╔═╡ 265cb418-e0c8-42ac-af58-d89f3c08ee4c
md"
- The traceplots and histogram of MCMC estimates/chains indicate unhealthy chains.
- Chains seem to drift around and spike occasionally to extreme values."

# ╔═╡ 15fe0e3d-b7a8-4bb5-9071-f6dfa6e84be2
let
	m13_7_df = DataFrame(m13_7_ch)
	@df m13_7_df scatter(:x, :v, alpha=0.7, xlabel="x", ylabel="v")
end

# ╔═╡ 613c00fc-def2-4ac1-9297-c2b1c1616b52
md"
- Explored space of x and v is uneven/assymetrical."

# ╔═╡ f6c7c0dd-eba5-4118-b854-a175ddde0ad5
md" ## Code 13.27 `m13_7nc`: non-centered version of `m13_7`.
- Distribution of x is no longer directly dependent on v."

# ╔═╡ fe449e67-fe7b-4713-a84b-f4a91f0d9380
@model function m13_7nc(N)
    v ~ Normal(0, 3)
    z ~ Normal()
    x = z * exp(v)
end

# ╔═╡ 8b56d961-3cca-4431-8d97-c33bd761387c
begin
	Random.seed!(5)
	@time m13_7nc_ch = sample(m13_7nc(1), NUTS(), 1000)
end

# ╔═╡ 9545b153-02cc-4904-96d9-a02b80fdfa02
plot(m13_7nc_ch, margin=5*Plots.mm)

# ╔═╡ 77e97975-cad6-4c42-9032-692b7ce6bf91
ess_rhat(m13_7nc_ch)

# ╔═╡ 3abe0fcf-fc84-4136-b62d-cff0667d0c1b
md"
- The MCMC chains are much healthier."

# ╔═╡ 4b709864-06c9-4808-9584-2673489e39ea
begin
	m13_7nc_df = DataFrame(m13_7nc_ch)
	@df m13_7nc_df scatter(:z, :v, alpha=0.7, xlabel="z", ylabel="v")
end

# ╔═╡ adfcb4f3-3946-4e12-ad4c-a6fe40fa2e91
scatter(m13_7nc_df.z .* exp.(m13_7nc_df.v), m13_7nc_df.v, alpha=0.7, xlabel="x", ylabel="v")


# ╔═╡ e792a8f5-ab93-4091-a775-5b26f01330ab
md"
- Exploration of the funnel is more comprehensive than the centered version."

# ╔═╡ a52b6a55-cf23-465b-b7d9-0bb741372d40
md" ## Code 13.28 `m13_4b`: refine HMC sampling
- Decrease init_ϵ to 0.1 (was 0.2).
- Increase acceptance rate from 0.95 to 0.99.
- Much slower: jumped from 40 seconds to 99 seconds. 
- This does not improve divergence much, much less than what's in the book.
- But Turing's initial result is much better than Stan."


# ╔═╡ d89aecb5-5fa1-4d94-b216-52a101c87747
md"

!!! note

There is no way to get amount of divergent samples, but they could be estimated by comparing `ess` values from the chain."

# ╔═╡ c38dc9ee-5cbb-47dd-a14a-cd185b4b4c46
begin
	Random.seed!(13)
	@time m13_4b_ch = sample(m13_4(chimpanzees.pulled_left, chimpanzees.actor, chimpanzees.block, chimpanzees.treatment),
		NUTS(0.99, init_ϵ=0.1), 4000)
end

# ╔═╡ f05cec5b-bb78-4e26-b5ea-e3e51c42a793
begin
	m13_4_ch_ess_rhat = ess_rhat(m13_4_ch)
	ess_4 = m13_4_ch_ess_rhat[:,:ess]
	m13_4b_ch_ess_rhat = ess_rhat(m13_4b_ch)
	ess_4b = m13_4b_ch_ess_rhat[:,:ess]
	
	p1 = plot(ess_4, lw=2, label="ESS m13_4")
	plot!(ess_4b, lw=2, label="ESS m13_4b")

	p2 = scatter(ess_4, ess_4b, 
		xlabel="ESS m13_4", ylabel="ESS m13_4b")
	plot!(identity, linestyle=:dash, c=:gray)

	plot(p1, p2, layout=(2,1), margin=5*Plots.mm, size=(800,800))
end

# ╔═╡ 41f0313d-2859-4751-ac3c-773626fd898b
let
	scatter(m13_4_ch_ess_rhat[:,:rhat], m13_4b_ch_ess_rhat[:,:rhat], 
			xlabel="rhat m13_4", ylabel="rhat m13_4b")
	plot!(identity, linestyle=:dash, c=:gray)
end

# ╔═╡ 9b59ade6-affb-4a20-aacb-c02967c201b0
md" ## Code 13.29 `m13_4nc`: non-centered version of `m13_4`.
- Reducing the number of hierarchies by one layer."

# ╔═╡ 486e7146-4bd2-4465-a562-bd2052c123e7
@model function m13_4nc(pulled_left, actor, block_id, treatment)
    σ_a ~ Exponential()
    σ_g ~ Exponential()
    ā ~ Normal(0, 1.5)
    no_of_actors = length(levels(actor))
    no_of_blocks = length(levels(block_id))
    no_of_treats = length(levels(treatment))
    z ~ filldist(Normal(), no_of_actors)
    x ~ filldist(Normal(), no_of_blocks)
    b ~ filldist(Normal(0, 0.5), no_of_treats)
    a = @. ā + σ_a*z
    g = σ_g*x
    
    p = @. logistic(a[actor] + g[block_id] + b[treatment])
    @. pulled_left ~ Binomial(1, p)
end

# ╔═╡ 12e79119-c060-4ac4-92e2-9658a1e9d587
begin
	Random.seed!(13)
	@time m13_4nc_ch = sample(m13_4nc(chimpanzees.pulled_left, chimpanzees.actor, chimpanzees.block, chimpanzees.treatment),
		NUTS(), 4000);
end

# ╔═╡ 71ff13f4-75fc-4b9a-95c2-e2d8cd7bfd5e
describe(DataFrame(m13_4nc_ch))

# ╔═╡ 27a37ed3-6f5e-400f-8192-4b937e651151
plot(m13_4nc_ch)

# ╔═╡ 374a5c3c-1034-4676-aa42-5b5917de5f74
ess_rhat(m13_4nc_ch)

# ╔═╡ d6b6a49f-a4d7-473b-9e46-324cd335b80a
md" ## Code 13.30 Improvement in `n_eff` of `m13_4nc` vs `m13_4`"

# ╔═╡ a4995532-cb86-4c30-bd3d-46b8f6a9253f
let
	t = ess_rhat(m13_4_ch)
	ess_4 = t[:,:ess]
	t = ess_rhat(m13_4nc_ch)
	ess_4nc = t[:,:ess]
	
	lims = extrema(vcat(ess_4, ess_4nc)) .+ (-100, 100)
	plot(xlim=lims, ylims=lims, xlab="n_eff (centered)", 
		ylab="n_eff (non-centered)", size=(500,500))
	scatter!(ess_4, ess_4nc)
	plot!(identity, c=:gray, s=:dash)
end

# ╔═╡ ef1c6253-944e-4647-aed2-c71df9ec2906
md" # 13.5 Multilevel posterior predictions."

# ╔═╡ 9bec6933-dd24-40b5-92a7-ca8956616ddd
md" ## Code 13.31 Posterior predictions from `m13_4` for actor 2.
- Actor 2 under 4 treatments from the 1st block."

# ╔═╡ 002ac714-3e07-40fb-83a2-a2f1c59cfc0f
let
	chimp = 2
	d_pred = DataFrame(
	    actor = fill(chimp, 4),
	    treatment = 1:4,
	    block = fill(1, 4)
	)
	
	l_fun = (r, dr) -> begin
	    a = get(r, "a[$(dr.actor)]", 0)
	    g = get(r, "g[$(dr.block)]", 0)
	    b = get(r, "b[$(dr.treatment)]", 0)
	    logistic(a + g + b)
	end
	
	@time p = link(m13_4_df, l_fun, eachrow(d_pred))
	@show size(p)
	p = hcat(p...)
	@show size(p)
	@show p_μ = mean.(eachcol(p))
	p_ci = PI.(eachcol(p));
end

# ╔═╡ 9384e567-cc37-425e-928f-9ec8cd8ec8e5
md" ## Code 13.32 Sample directly from the chain"

# ╔═╡ 14745152-0313-489e-a668-b17cfa7d0cfd
begin
	@time post13_4 = sample(resetrange(m13_4_ch), 2000)
	post13_4_df = DataFrame(post13_4)
	describe(post13_4_df)
end

# ╔═╡ 00b8fb2f-d32f-4a92-a113-3a5ae91a7069
let
	p_matrix = @. logistic(post13_4_df[:,"a[2]"] + post13_4_df[:,"g[1]"] + 
		post13_4_df[:, r"b"])
	@show typeof(p_matrix)
	@show p_μ = mean.(eachcol(p_matrix))
	p_ci = PI.(eachcol(p_matrix));
end

# ╔═╡ 408f1638-3ad5-4502-97db-e045f0845422
md"
- Results are very similar to Code 13.31"

# ╔═╡ fe42ac20-c7f2-416b-af21-e4dccbc4f436
md" ## Code 13.33 Histogram of actor 5 odds-ratio"

# ╔═╡ aad99eb9-7ee2-4beb-b461-ccdc45ba04b9
density(post13_4_df."a[5]")

# ╔═╡ 16edfd3e-26e0-47b7-a36c-e4144ca53d38
md" ## Code 13.34 `p_link`: function to obtain probability of pull for any actor/block/treatment"

# ╔═╡ 30b9de2d-97e5-4d7c-9042-1018dfc53b3a
p_link = (actor, block_id, treatment) -> begin
    logodds = 
        getproperty(post13_4_df, "a[$actor]") + 
        getproperty(post13_4_df, "g[$block_id]") + 
        getproperty(post13_4_df, "b[$treatment]")
    logistic.(logodds)
end

# ╔═╡ a61f6f9f-4941-4d3a-aef9-f556df6ff9a8
md"
- Bug in the original p_link()."

# ╔═╡ 43f08753-8307-4094-b183-5ef7017e3a1e
md" ## Code 13.35 Use `p_link` to obtain p CI for actor 2, block 1, & treatment 1:4"

# ╔═╡ e90c9e4c-5c00-4253-b6b8-ad9c7b749e95
begin
	p_raw = p_link.(2, 1, 1:4)
	p_raw = hcat(p_raw...)
	@show p_μ = mean.(eachcol(p_raw))
	p_ci = PI.(eachcol(p_raw));
end

# ╔═╡ b34a1f96-0d66-4031-9a99-20e73780c7c5
md" ## Code 13.36 Posterior prediction for a new cluster/chimp"

# ╔═╡ c57afb19-d62d-4e8c-b2dd-2b176a6280e0
p_link_abar = treatment -> begin
    logodds = post13_4_df.ā + getproperty(post13_4_df, "b[$treatment]")
    logistic.(logodds)
end

# ╔═╡ 30dd6108-a341-423e-91ba-c29a99b37cb7
md"
- ̄a represents the odds-ratio of a new monkey.
- Ignore block because this is a new block. And average block effect is zero."


# ╔═╡ d015e9cf-a420-43eb-a058-b5eac0e10662
md" ## Code 13.37 Prediction for a new/average actor"

# ╔═╡ d359891c-eefd-4e2a-94c7-0d20f35c61f6
let
	p_raw = p_link_abar.(1:4)
	@show size(p_raw)
	p_raw = hcat(p_raw...)
	@show size(p_raw)
	@show p_μ = mean.(eachcol(p_raw))
	@show size(p_μ)
	p_ci = PI.(eachcol(p_raw))
	@show p_ci = vcat(p_ci'...)
	@show size(p_ci)
	plot(xlab="treatment", ylab="proportion pulled left", 
		title="average actor", ylim=(0, 1))
	plot!(["R/N", "L/N", "R/P", "L/P"], [p_μ p_μ], fillrange=p_ci, 
		fillalpha=0.2, c=:black, lw=1.5)
end

# ╔═╡ d4de4418-316d-4976-a5aa-0923346eb0be
md" ## Code 13.38 Simulate actor `odds_ratio` considering the variance `σ_a`."

# ╔═╡ 7f4622a8-f2ea-41bf-a04e-f9f69faec4a3
let
	Random.seed!(1)
	# considering σ_a dramatically increases the variation of a.
	a_sim = rand.(Normal.(post13_4_df.ā, post13_4_df.σ_a))
	
	p_link_asim = treatment -> begin
	    logodds = a_sim + getproperty(post13_4_df, "b[$treatment]")
	    logistic.(logodds)
	end
	
	global p_raw_asim = p_link_asim.(1:4)
	p_raw_asim = hcat(p_raw_asim...)
	@show p_μ = mean.(eachcol(p_raw_asim))
	p_ci = PI.(eachcol(p_raw_asim))
	@show p_ci = vcat(p_ci'...)
	
	plot(xlab="treatment", ylab="proportion pulled left", title="marginal of actor", ylim=(0, 1))
	plot!(["R/N", "L/N", "R/P", "L/P"], [p_μ p_μ], fillrange=p_ci, fillalpha=0.2, c=:black, lw=1.5)
end

# ╔═╡ 41920919-0df9-42bf-9749-268a3a5906c2
md" ## Code 13.39 Visualize how each actor changes across four treatments."

# ╔═╡ 7864f790-f9a0-447b-aad5-c56c0f3e1f34
let
	p = plot(xlab="treatment", ylab="proportion pulled left", title="simulated actors", ylim=(0, 1))
	
	for r in first(eachrow(p_raw_asim), 100)
	    plot!(["R/N", "L/N", "R/P", "L/P"], r, c=:black, alpha=0.2)
	end
	p
end

# ╔═╡ 96439721-98b1-4246-bdb4-d32dec3857a6
md"
- Note the interaction between the treatment and intercept of each actor.
- Near the top and bottom, treatment has little effect.
- Nera the mean, treatment has larger effect."

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
DrWatson = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
FreqTables = "da1fdf0e-e0ff-5433-a45f-9bb5ff651cb1"
Logging = "56ddb016-857b-54e1-b83d-db4d58db5568"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
ParetoSmooth = "a68b5a21-f429-434e-8bfa-46b447300aac"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
StatisticalRethinking = "2d09df54-9d0f-5258-8220-54c2a3d4fbee"
StatisticalRethinkingPlots = "e1a513d0-d9d9-49ff-a6dd-9d2e9db473da"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
StatsPlots = "f3b207a7-027a-5e70-b257-86293d7955fd"
Turing = "fce5fe82-541a-59a6-adf8-730c64b5f9a0"

[compat]
CSV = "~0.10.12"
DataFrames = "~1.6.1"
Distributions = "~0.25.107"
DrWatson = "~2.13.0"
FreqTables = "~0.4.6"
Optim = "~1.8.0"
ParetoSmooth = "~0.7.7"
Plots = "~1.40.0"
PlutoUI = "~0.7.59"
StatisticalRethinking = "~4.7.3"
StatisticalRethinkingPlots = "~1.1.0"
StatsBase = "~0.34.2"
StatsPlots = "~0.15.6"
Turing = "~0.25.3"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.2"
manifest_format = "2.0"
project_hash = "dcd38df8ffacddb50bcd44abc614467ffdeed595"

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
deps = ["BangBang", "ConsoleProgressMonitor", "Distributed", "LogDensityProblems", "Logging", "LoggingExtras", "ProgressLogging", "Random", "StatsBase", "TerminalLoggers", "Transducers"]
git-tree-sha1 = "87e63dcb990029346b091b170252f3c416568afc"
uuid = "80f14c24-f653-4e6a-9b94-39d6b0f70001"
version = "4.4.2"

[[deps.AbstractPPL]]
deps = ["AbstractMCMC", "DensityInterface", "Random", "Setfield", "SparseArrays"]
git-tree-sha1 = "33ea6c6837332395dbf3ba336f273c9f7fcf4db9"
uuid = "7a57a42e-76ec-4ea3-a279-07e840d6d9cf"
version = "0.5.4"

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
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Markdown", "Test"]
git-tree-sha1 = "c0d491ef0b135fd7d63cbc6404286bc633329425"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.36"
weakdeps = ["AxisKeys", "IntervalSets", "Requires", "StaticArrays", "StructArrays", "Unitful"]

    [deps.Accessors.extensions]
    AccessorsAxisKeysExt = "AxisKeys"
    AccessorsIntervalSetsExt = "IntervalSets"
    AccessorsStaticArraysExt = "StaticArrays"
    AccessorsStructArraysExt = "StructArrays"
    AccessorsUnitfulExt = "Unitful"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cde29ddf7e5726c9fb511f340244ea3481267608"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.7.2"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AdvancedHMC]]
deps = ["AbstractMCMC", "ArgCheck", "DocStringExtensions", "InplaceOps", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "ProgressMeter", "Random", "Requires", "Setfield", "SimpleUnPack", "Statistics", "StatsBase", "StatsFuns"]
git-tree-sha1 = "3bf24030e85b1d6d298e4f483f6aeff6f38462db"
uuid = "0bf59076-c3b1-5ca4-86bd-e02cd72cde3d"
version = "0.4.6"

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
git-tree-sha1 = "b2a1602952739e589cf5e2daff1274a49f22c9a4"
uuid = "5b7e9947-ddc0-4b3f-9b55-0d8042f74170"
version = "0.7.5"
weakdeps = ["DiffResults", "ForwardDiff", "MCMCChains", "StructArrays"]

    [deps.AdvancedMH.extensions]
    AdvancedMHForwardDiffExt = ["DiffResults", "ForwardDiff"]
    AdvancedMHMCMCChainsExt = "MCMCChains"
    AdvancedMHStructArraysExt = "StructArrays"

[[deps.AdvancedPS]]
deps = ["AbstractMCMC", "Distributions", "Libtask", "Random", "Random123", "StatsFuns"]
git-tree-sha1 = "4d73400b3583147b1b639794696c78202a226584"
uuid = "576499cb-2369-40b2-a588-c64705576edc"
version = "0.4.3"

[[deps.AdvancedVI]]
deps = ["ADTypes", "Bijectors", "DiffResults", "Distributions", "DistributionsAD", "DocStringExtensions", "ForwardDiff", "LinearAlgebra", "ProgressMeter", "Random", "Requires", "StatsBase", "StatsFuns", "Tracker"]
git-tree-sha1 = "187f67ab998f25208651262fee9539d845016b26"
uuid = "b5ca4192-6429-45e5-a2d9-87aec30a685c"
version = "0.2.5"

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
deps = ["Random"]
git-tree-sha1 = "82b912bb5215792fd33df26f407d064d3602af98"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.2"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

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
deps = ["Adapt", "LinearAlgebra", "Requires", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "c5aeb516a84459e0318a02507d2261edad97eb75"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.7.1"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

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

[[deps.AxisKeys]]
deps = ["IntervalSets", "LinearAlgebra", "NamedDims", "Tables"]
git-tree-sha1 = "2404d61946c5d17a120101dbc753739ef216b0de"
uuid = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
version = "0.2.14"

    [deps.AxisKeys.extensions]
    AbstractFFTsExt = "AbstractFFTs"
    ChainRulesCoreExt = "ChainRulesCore"
    CovarianceEstimationExt = "CovarianceEstimation"
    InvertedIndicesExt = "InvertedIndices"
    LazyStackExt = "LazyStack"
    OffsetArraysExt = "OffsetArrays"
    StatisticsExt = "Statistics"
    StatsBaseExt = "StatsBase"

    [deps.AxisKeys.weakdeps]
    AbstractFFTs = "621f4979-c628-5d54-868e-fcf4e3e8185c"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    CovarianceEstimation = "587fd27a-f159-11e8-2dae-1979310e6154"
    InvertedIndices = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
    LazyStack = "1fad7336-0346-5a1a-a56f-a06ba010965b"
    OffsetArrays = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
    StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

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
deps = ["ArgCheck", "ChainRulesCore", "ChangesOfVariables", "Compat", "Distributions", "Functors", "InverseFunctions", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "MappedArrays", "Random", "Reexport", "Requires", "Roots", "SparseArrays", "Statistics"]
git-tree-sha1 = "ff192d037dee3c05fe842a207f8c6b840b04cca2"
uuid = "76274a88-744f-5084-9051-94815aaf08c4"
version = "0.12.8"

    [deps.Bijectors.extensions]
    BijectorsDistributionsADExt = "DistributionsAD"
    BijectorsForwardDiffExt = "ForwardDiff"
    BijectorsLazyArraysExt = "LazyArrays"
    BijectorsReverseDiffExt = "ReverseDiff"
    BijectorsTrackerExt = "Tracker"
    BijectorsZygoteExt = "Zygote"

    [deps.Bijectors.weakdeps]
    DistributionsAD = "ced4e74d-a319-5a8a-b0ac-84af2272839c"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.BitFlags]]
git-tree-sha1 = "2dc09997850d68179b69dafb58ae806167a32b1b"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.8"

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "0c5f81f47bbbcf4aea7b2959135713459170798b"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.5"

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
git-tree-sha1 = "601f7e7b3d36f18790e2caf83a882d88e9b71ff1"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.4"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "6c834533dc1fabd820c1db03c839bf97e45a3fab"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.14"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a4c43f59baa34011e303e76f5c8c91bf58415aaf"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.18.0+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "1568b28f91293458345dabba6a5ea3f183250a61"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.8"

    [deps.CategoricalArrays.extensions]
    CategoricalArraysJSONExt = "JSON"
    CategoricalArraysRecipesBaseExt = "RecipesBase"
    CategoricalArraysSentinelArraysExt = "SentinelArrays"
    CategoricalArraysStructTypesExt = "StructTypes"

    [deps.CategoricalArrays.weakdeps]
    JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SentinelArrays = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
    StructTypes = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "SparseInverseSubset", "Statistics", "StructArrays", "SuiteSparse"]
git-tree-sha1 = "291821c1251486504f6bae435227907d734e94d2"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.66.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "575cd02e080939a33b6df6c5853d14924c08e35b"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.23.0"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "2fba81a302a7be671aefe194f0525ef231104e7f"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.8"
weakdeps = ["InverseFunctions"]

    [deps.ChangesOfVariables.extensions]
    ChangesOfVariablesInverseFunctionsExt = "InverseFunctions"

[[deps.Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "Random", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "9ebb045901e9bbf58767a9f34ff89831ed711aae"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.15.7"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "Libdl", "TranscodingStreams"]
git-tree-sha1 = "9b1ca1aa6ce3f71b3d1840c538a8210a043625eb"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "59939d8a997469ee05c4b4944560a820f9ba0d73"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.4"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "4b270d6465eb21ae89b732182c20dc165f8bf9f2"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.25.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

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
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSolve]]
git-tree-sha1 = "0eee5eb66b1cf62cd6ad1b460238e60e4b09400c"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.4"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "b1c55339b7c6c350ee89f2c1604299660525b248"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.15.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.0+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "6cbbd4d241d7e6579ab354737f4dd95ca43946e1"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.1"

[[deps.ConsoleProgressMonitor]]
deps = ["Logging", "ProgressMeter"]
git-tree-sha1 = "3ab7b2136722890b9af903859afcf457fa3059e8"
uuid = "88cd18e8-d9cc-4ea6-8889-5259c0d15c8b"
version = "0.1.2"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "260fd2400ed2dab602a7c15cf10c1933c59930a2"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.5"
weakdeps = ["IntervalSets", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
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

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "22c595ca4146c07b16bcf9c8bea86f731f7109d2"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.108"
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
deps = ["ANSIColoredPrinters", "AbstractTrees", "Base64", "CodecZlib", "Dates", "DocStringExtensions", "Downloads", "Git", "IOCapture", "InteractiveUtils", "JSON", "LibGit2", "Logging", "Markdown", "MarkdownAST", "Pkg", "PrecompileTools", "REPL", "RegistryInstances", "SHA", "TOML", "Test", "Unicode"]
git-tree-sha1 = "5461b2a67beb9089980e2f8f25145186b6d34f91"
uuid = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
version = "1.4.1"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DrWatson]]
deps = ["Dates", "FileIO", "JLD2", "LibGit2", "MacroTools", "Pkg", "Random", "Requires", "Scratch", "UnPack"]
git-tree-sha1 = "f83dbe0ef99f1cf32b815f0dad632cb25129604e"
uuid = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
version = "2.13.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.DynamicPPL]]
deps = ["AbstractMCMC", "AbstractPPL", "BangBang", "Bijectors", "ChainRulesCore", "ConstructionBase", "Distributions", "DocStringExtensions", "LinearAlgebra", "LogDensityProblems", "MacroTools", "OrderedCollections", "Random", "Setfield", "Test", "ZygoteRules"]
git-tree-sha1 = "9413ced9747ba9ff93545ccdb264b765c51c3220"
uuid = "366bfd00-2699-11ea-058f-f148b4cae6d8"
version = "0.22.4"

[[deps.EllipticalSliceSampling]]
deps = ["AbstractMCMC", "ArrayInterface", "Distributions", "Random", "Statistics"]
git-tree-sha1 = "973b4927d112559dc737f55d6bf06503a5b3fc14"
uuid = "cad2338a-1db2-11e9-3401-43bc07c9ede2"
version = "1.1.0"

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

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

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
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "82d8afa92ecf4b52d78d869f038ebfb881267322"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.3"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "9f00e42f8d99fdde64d40c8ea5d14269a2e2c1aa"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.21"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "0653c0a2396a6da5bc4766c43041ef5fd3efbe57"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.11.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "2de436b72c3422940cbe1367611d137008af7ec3"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.23.1"

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
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Zlib_jll"]
git-tree-sha1 = "db16beca600632c95fc8aca29890d83788dd8b23"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.96+0"

[[deps.Format]]
git-tree-sha1 = "9c68794ef81b08086aeb32eeaf33531668d5f5fc"
uuid = "1fa38f19-a742-5d3f-a2b9-30dd87b9d5f8"
version = "1.3.7"

[[deps.Formatting]]
deps = ["Logging", "Printf"]
git-tree-sha1 = "fb409abab2caf118986fc597ba84b50cbaf00b87"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.3"

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
git-tree-sha1 = "d8db6a5a2fe1381c1ea4ef2cab7c69c2de7f9ea0"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.13.1+0"

[[deps.FreqTables]]
deps = ["CategoricalArrays", "Missings", "NamedArrays", "Tables"]
git-tree-sha1 = "4693424929b4ec7ad703d68912a6ad6eff103cfe"
uuid = "da1fdf0e-e0ff-5433-a45f-9bb5ff651cb1"
version = "0.4.6"

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
git-tree-sha1 = "d3e63d9fa13f8eaa2f06f64949e2afc593ff52c2"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.4.10"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "ff38ba61beff76b8f4acad8ab0c97ef73bb670cb"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.9+0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "2d6ca471a6c7b536127afccfa7564b5b39227fe0"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.5"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "p7zip_jll"]
git-tree-sha1 = "ddda044ca260ee324c5fc07edb6d7cf3f0b9c350"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.5"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "278e5e0f820178e8a26df3184fcb2280717c79b1"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.5+0"

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

[[deps.Git]]
deps = ["Git_jll"]
git-tree-sha1 = "04eff47b1354d702c3a85e8ab23d539bb7d5957e"
uuid = "d7ba0133-e1db-5d97-8f8c-041e4b3a1eb2"
version = "1.3.1"

[[deps.Git_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "LibCURL_jll", "Libdl", "Libiconv_jll", "OpenSSL_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "d18fb8a1f3609361ebda9bf029b60fd0f120c809"
uuid = "f8c6e375-362e-5223-8a59-34ff63f689eb"
version = "2.44.0+2"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Zlib_jll"]
git-tree-sha1 = "359a1ba2e320790ddbe4ee8b4d54a305c0ea2aff"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.80.0+0"

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
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Static"]
git-tree-sha1 = "eb8fed28f4994600e29beef49744639d985a04b2"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.16"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "f218fe3736ddf977e0e772bc9a586b2383da2685"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.23"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "8b72179abc660bfab5e28472e019392b97d0985c"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.4"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InplaceOps]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "50b41d59e7164ab6fda65e71049fee9d890731ff"
uuid = "505f98c9-085e-5b2c-8e89-488be7bf1f34"
version = "0.3.0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be50fe8df3acbffa0274a744f1a99d29c45a57f4"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.1.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

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
deps = ["Test"]
git-tree-sha1 = "e7cbed5032c4c397a6ac23d1493f3289e01231c4"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.14"
weakdeps = ["Dates"]

    [deps.InverseFunctions.extensions]
    DatesExt = "Dates"

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
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "Pkg", "PrecompileTools", "Printf", "Reexport", "Requires", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "5ea6acdd53a51d897672edb694e3cc2912f3f8a7"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.46"

[[deps.JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "a53ebe394b71470c7f97c2e7e170d51df21b17af"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.7"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c84a835e1a09b289ffcd2271bf2a337bbdda6637"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.3+0"

[[deps.KernelAbstractions]]
deps = ["Adapt", "Atomix", "InteractiveUtils", "LinearAlgebra", "MacroTools", "PrecompileTools", "Requires", "SparseArrays", "StaticArrays", "UUIDs", "UnsafeAtomics", "UnsafeAtomicsLLVM"]
git-tree-sha1 = "ed7167240f40e62d97c1f5f7735dea6de3cc5c49"
uuid = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
version = "0.9.18"

    [deps.KernelAbstractions.extensions]
    EnzymeExt = "EnzymeCore"

    [deps.KernelAbstractions.weakdeps]
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"

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
git-tree-sha1 = "839c82932db86740ae729779e610f07a1640be9a"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "6.6.3"

    [deps.LLVM.extensions]
    BFloat16sExt = "BFloat16s"

    [deps.LLVM.weakdeps]
    BFloat16s = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "88b916503aac4fb7f701bb625cd84ca5dd1677bc"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.29+0"

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d986ce2d884d49126836ea94ed5bfb0f12679713"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "15.0.7+0"

[[deps.LRUCache]]
git-tree-sha1 = "b3cc6698599b10e652832c2f23db3cab99d51b59"
uuid = "8ac3fa9e-de4c-5943-b1dc-09c6b5f20637"
version = "1.6.1"
weakdeps = ["Serialization"]

    [deps.LRUCache.extensions]
    SerializationExt = ["Serialization"]

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "70c5da094887fd2cae843b8db33920bac4b6f07d"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.2+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "e0b5cd21dc1b44ec6e64f351976f961e6f31d6c4"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.3"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SymEngineExt = "SymEngine"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"

[[deps.LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "62edfee3211981241b57ff1cedf4d74d79519277"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.15"

[[deps.LazilyInitializedFields]]
git-tree-sha1 = "8f7f3cabab0fd1800699663533b6d5cb3fc0e612"
uuid = "0e77f7df-68c5-4e49-93ce-4cd80f5598bf"
version = "1.2.2"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

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
version = "8.4.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.6.4+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

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

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "7bbea35cec17305fc70a0e5b4641477dc0789d9d"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.2.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

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
git-tree-sha1 = "18144f3e9cbe9b15b070288eef858f71b291ce37"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.27"
weakdeps = ["ChainRulesCore", "ChangesOfVariables", "InverseFunctions"]

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

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

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "80b2833b56d466b3858d565adcd16a4a05f2089b"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.1.0+0"

[[deps.MLJModelInterface]]
deps = ["Random", "ScientificTypesBase", "StatisticalTraits"]
git-tree-sha1 = "d2a45e1b5998ba3fdfb6cfe0c81096d4c7fb40e7"
uuid = "e80e1ace-859a-464e-9ed9-23947d8ae3ea"
version = "1.9.6"

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

[[deps.MarkdownAST]]
deps = ["AbstractTrees", "Markdown"]
git-tree-sha1 = "465a70f0fc7d443a00dcdc3267a497397b8a3899"
uuid = "d0879d2d-cac2-40c8-9cee-1863dc0c7391"
version = "0.1.2"

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "9cc5acd6b76174da7503d1de3a6f8cf639b6e5cb"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.29.0"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+1"

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

[[deps.MonteCarloMeasurements]]
deps = ["Distributed", "Distributions", "ForwardDiff", "GenericSchur", "LinearAlgebra", "MacroTools", "Random", "RecipesBase", "Requires", "SLEEFPirates", "StaticArrays", "Statistics", "StatsBase", "Test"]
git-tree-sha1 = "19d4a73e20ca54f0f0e8a4ed349ee0dfd6e997b7"
uuid = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
version = "1.1.6"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.1.10"

[[deps.MultivariateStats]]
deps = ["Arpack", "LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI", "StatsBase"]
git-tree-sha1 = "68bf5103e002c44adfd71fea6bd770b3f0586843"
uuid = "6f286f6a-111f-5878-ab1e-185364afe411"
version = "0.10.2"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "a3589efe0005fc4718775d8641b2de9060d23f73"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.4.4"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NNlib]]
deps = ["Adapt", "Atomix", "ChainRulesCore", "GPUArraysCore", "KernelAbstractions", "LinearAlgebra", "Pkg", "Random", "Requires", "Statistics"]
git-tree-sha1 = "5055845dd316575ae2fc1f6dcb3545ff15fe547a"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.9.14"

    [deps.NNlib.extensions]
    NNlibAMDGPUExt = "AMDGPU"
    NNlibCUDACUDNNExt = ["CUDA", "cuDNN"]
    NNlibCUDAExt = "CUDA"
    NNlibEnzymeCoreExt = "EnzymeCore"

    [deps.NNlib.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"
    cuDNN = "02a925ec-e4fe-4b08-9a7e-0d78e3d38ccd"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NamedArrays]]
deps = ["Combinatorics", "DataStructures", "DelimitedFiles", "InvertedIndices", "LinearAlgebra", "Random", "Requires", "SparseArrays", "Statistics"]
git-tree-sha1 = "b84e17976a40cb2bfe3ae7edb3673a8c630d4f95"
uuid = "86f7a689-2022-50b4-a561-43c23ac3c673"
version = "0.9.8"

[[deps.NamedDims]]
deps = ["LinearAlgebra", "Pkg", "Statistics"]
git-tree-sha1 = "90178dc801073728b8b2d0d8677d10909feb94d8"
uuid = "356022a1-0364-5f58-8944-0da4b18d706f"
version = "1.2.2"

    [deps.NamedDims.extensions]
    AbstractFFTsExt = "AbstractFFTs"
    ChainRulesCoreExt = "ChainRulesCore"
    CovarianceEstimationExt = "CovarianceEstimation"
    TrackerExt = "Tracker"

    [deps.NamedDims.weakdeps]
    AbstractFFTs = "621f4979-c628-5d54-868e-fcf4e3e8185c"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    CovarianceEstimation = "587fd27a-f159-11e8-2dae-1979310e6154"
    Requires = "ae029012-a4dd-5104-9daa-d747884805df"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

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
git-tree-sha1 = "ded64ff6d4fdd1cb68dfcbb818c69e144a5b2e4c"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.16"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Observables]]
git-tree-sha1 = "7438a59546cf62428fc9d1bc94729146d37a7225"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.5"

[[deps.OffsetArrays]]
git-tree-sha1 = "e64b4f5ea6b7389f6f046d13d4896a8f9c1ba71e"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.14.0"
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
version = "0.3.23+4"

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
git-tree-sha1 = "3da7367955dcc5c54c1ba4d402ccdc09a1a3e046"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.13+1"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "MathOptInterface", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "f55af9918e2a67dcadf5ec758a5ff25746c3819f"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.8.0"

[[deps.Optimisers]]
deps = ["ChainRulesCore", "Functors", "LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "6572fe0c5b74431aaeb0b18a4aa5ef03c84678be"
uuid = "3bd65402-5787-11e9-1adc-39752487f4e2"
version = "0.3.3"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

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

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.ParetoSmooth]]
deps = ["AxisKeys", "LinearAlgebra", "LogExpFunctions", "MCMCDiagnosticTools", "NamedDims", "PrettyTables", "Printf", "Random", "Requires", "Statistics", "StatsBase"]
git-tree-sha1 = "3816447a82da1da83e5c8d5d159d289f2eb82b13"
uuid = "a68b5a21-f429-434e-8bfa-46b447300aac"
version = "0.7.9"
weakdeps = ["DynamicPPL", "MCMCChains"]

    [deps.ParetoSmooth.extensions]
    ParetoSmoothDynamicPPLExt = ["DynamicPPL", "MCMCChains"]
    ParetoSmoothMCMCChainsExt = "MCMCChains"

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
git-tree-sha1 = "64779bc4c9784fee475689a1752ef4d5747c5e87"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.42.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.10.0"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "1f03a2d339f42dca4a4da149c7e15e9b896ad899"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.1.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "7b1a9df27f072ac4c9c7cbe5efb198489258d1f5"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.1"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "UnitfulLatexify", "Unzip"]
git-tree-sha1 = "442e1e7ac27dd5ff8825c3fa62fbd1e86397974b"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.40.4"

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
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "ab55ee1510ad2af0ff674dbcced5e94921f867a9"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.59"

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
git-tree-sha1 = "88b895d13d53b5577fd53379d913b9ab9ac82660"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "763a8ceb07833dd51bb9e3bbca372de32c0605ad"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.0"

[[deps.Qt6Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Vulkan_Loader_jll", "Xorg_libSM_jll", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_cursor_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "libinput_jll", "xkbcommon_jll"]
git-tree-sha1 = "37b7bb7aabf9a085e0044307e1717436117f2b3b"
uuid = "c0090381-4147-56d7-9ebc-da0b1113ec56"
version = "6.5.3+1"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9b23c31e76e333e6fb4c1595ae6afa74966a729e"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.9.4"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Random123]]
deps = ["Random", "RandomNumbers"]
git-tree-sha1 = "4743b43e5a9c4a2ede372de7061eed81795b12e7"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.7.0"

[[deps.RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

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
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "Requires", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "d7087c013e8a496ff396bae843b1e16d9a30ede8"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.38.10"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RegistryInstances]]
deps = ["LazilyInitializedFields", "Pkg", "TOML", "Tar"]
git-tree-sha1 = "ffd19052caf598b8653b99404058fce14828be51"
uuid = "2792f1a3-b283-48e8-9a74-f99dce5104f3"
version = "0.1.0"

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
git-tree-sha1 = "f65dcb5fa46aee0cf9ed6274ccbd597adc49aa7b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.1"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6ed52fdd3382cf21947b15e8870ac0ddbff736da"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.4.0+0"

[[deps.Roots]]
deps = ["Accessors", "ChainRulesCore", "CommonSolve", "Printf"]
git-tree-sha1 = "1ab580704784260ee5f45bffac810b152922747b"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "2.1.5"

    [deps.Roots.extensions]
    RootsForwardDiffExt = "ForwardDiff"
    RootsIntervalRootFindingExt = "IntervalRootFinding"
    RootsSymPyExt = "SymPy"
    RootsSymPyPythonCallExt = "SymPyPythonCall"

    [deps.Roots.weakdeps]
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
git-tree-sha1 = "3aac6d68c5e57449f5b9b865c9ba50ac2970c4cf"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.42"

[[deps.SciMLBase]]
deps = ["ADTypes", "ArrayInterface", "ChainRulesCore", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FillArrays", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "PrecompileTools", "Preferences", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables", "TruncatedStacktraces", "ZygoteRules"]
git-tree-sha1 = "916b8a94c0d61fa5f7c5295649d3746afb866aff"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "1.98.1"

    [deps.SciMLBase.extensions]
    ZygoteExt = "Zygote"

    [deps.SciMLBase.weakdeps]
    Zygote = "e88e6eb3-aa80-5325-afca-941959d7151f"

[[deps.SciMLOperators]]
deps = ["ArrayInterface", "DocStringExtensions", "LinearAlgebra", "MacroTools", "Setfield", "SparseArrays", "StaticArraysCore"]
git-tree-sha1 = "10499f619ef6e890f3f4a38914481cc868689cd5"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "0.3.8"

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
git-tree-sha1 = "363c4e82b66be7b9f7c7c7da7478fdae07de44b9"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.2"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.SimpleUnPack]]
git-tree-sha1 = "58e6353e72cde29b90a69527e56df1b5c3d8c437"
uuid = "ce78b400-467f-4804-87d8-8f486da07d0a"
version = "1.1.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.10.0"

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
deps = ["IfElse"]
git-tree-sha1 = "d2fdac9ff3906e27f7a618d47b676941baa6c80c"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.8.10"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "Requires", "SparseArrays", "Static", "SuiteSparse"]
git-tree-sha1 = "5d66818a39bb04bf328e92bc933ec5b4ee88e436"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.5.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "bf074c045d3d5ffd956fa0a461da38a44685d6b2"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.3"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "36b3d696ce6366023a0ea192b4cd442268995a0d"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.2"

[[deps.StatisticalRethinking]]
deps = ["CSV", "DataFrames", "Dates", "Distributions", "DocStringExtensions", "Documenter", "Formatting", "KernelDensity", "LinearAlgebra", "MCMCChains", "MonteCarloMeasurements", "NamedArrays", "NamedTupleTools", "Optim", "OrderedCollections", "Parameters", "ParetoSmoothedImportanceSampling", "PrettyTables", "Random", "Reexport", "Requires", "Statistics", "StatsBase", "StatsFuns", "StructuralCausalModels", "Tables", "Test", "Unicode"]
git-tree-sha1 = "08a543e968a379b3a5d04c2acc25a3f8310e9961"
uuid = "2d09df54-9d0f-5258-8220-54c2a3d4fbee"
version = "4.7.3"

[[deps.StatisticalRethinkingPlots]]
deps = ["Distributions", "DocStringExtensions", "KernelDensity", "LaTeXStrings", "Parameters", "Plots", "Reexport", "Requires", "StatisticalRethinking", "StatsPlots"]
git-tree-sha1 = "bd7bd318815654491e6350c662020119be7792a0"
uuid = "e1a513d0-d9d9-49ff-a6dd-9d2e9db473da"
version = "1.1.0"

[[deps.StatisticalTraits]]
deps = ["ScientificTypesBase"]
git-tree-sha1 = "30b9236691858e13f167ce829490a68e1a597782"
uuid = "64bff920-2084-43da-a3e6-9bb72801c0c9"
version = "3.2.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.10.0"

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
git-tree-sha1 = "cef0472124fab0695b58ca35a77c6fb942fdab8a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.1"
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
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

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
git-tree-sha1 = "01c838be8d7119708b839aa16d413088a1076ee8"
uuid = "a41e6734-49ce-4065-8b83-aff084c01dfd"
version = "1.4.1"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.SymbolicIndexingInterface]]
deps = ["DocStringExtensions"]
git-tree-sha1 = "f8ab052bfcbdb9b48fad2c80c873aa0d0344dfe5"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.2.2"

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
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "cb76cf677714c095e535e3501ac7954732aeea2d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.1"

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

[[deps.Tracker]]
deps = ["Adapt", "ChainRulesCore", "DiffRules", "ForwardDiff", "Functors", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NNlib", "NaNMath", "Optimisers", "Printf", "Random", "Requires", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "5158100ed55411867674576788e710a815a0af02"
uuid = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
version = "0.2.34"
weakdeps = ["PDMats"]

    [deps.Tracker.extensions]
    TrackerPDMatsExt = "PDMats"

[[deps.TranscodingStreams]]
git-tree-sha1 = "5d54d076465da49d6746c647022f3b3674e64156"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.8"
weakdeps = ["Random", "Test"]

    [deps.TranscodingStreams.extensions]
    TestExt = ["Test", "Random"]

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
git-tree-sha1 = "eae1bb484cd63b36999ee58be2de6c178105112f"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.8"

[[deps.TruncatedStacktraces]]
deps = ["InteractiveUtils", "MacroTools", "Preferences"]
git-tree-sha1 = "ea3e54c2bdde39062abf5a9758a23735558705e1"
uuid = "781d530d-4396-4725-bb49-402e4bee1e77"
version = "1.4.0"

[[deps.Turing]]
deps = ["AbstractMCMC", "AdvancedHMC", "AdvancedMH", "AdvancedPS", "AdvancedVI", "BangBang", "Bijectors", "DataStructures", "Distributions", "DistributionsAD", "DocStringExtensions", "DynamicPPL", "EllipticalSliceSampling", "ForwardDiff", "Libtask", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "MCMCChains", "NamedArrays", "Printf", "Random", "Reexport", "Requires", "SciMLBase", "Setfield", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Tracker"]
git-tree-sha1 = "ba813a7dad626fcd099f941598bc41667d3ecc54"
uuid = "fce5fe82-541a-59a6-adf8-730c64b5f9a0"
version = "0.25.3"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "3c793be6df9dd77a0cf49d80984ef9ff996948fa"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.19.0"
weakdeps = ["ConstructionBase", "InverseFunctions"]

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "e2d817cc500e960fdbafcf988ac8436ba3208bfd"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.6.3"

[[deps.UnsafeAtomics]]
git-tree-sha1 = "6331ac3440856ea1988316b46045303bef658278"
uuid = "013be700-e6cd-48c3-b4a1-df204f14c38f"
version = "0.2.1"

[[deps.UnsafeAtomicsLLVM]]
deps = ["LLVM", "UnsafeAtomics"]
git-tree-sha1 = "323e3d0acf5e78a56dfae7bd8928c989b4f3083e"
uuid = "d80eeb9a-aca5-4d75-85e5-170c8b632249"
version = "0.1.3"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.VectorizationBase]]
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "6129a4faf6242e7c3581116fbe3270f3ab17c90d"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.67"

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
git-tree-sha1 = "532e22cf7be8462035d092ff21fada7527e2c488"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.12.6+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

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
git-tree-sha1 = "b4bfde5d5b652e22b9c790ad00af08b6d042b97d"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.15.0+0"

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
git-tree-sha1 = "e678132f07ddb5bfa46857f0d7620fb9be675d3b"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.6+0"

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
git-tree-sha1 = "a68c9655fbe6dfcab3d972808f1aafec151ce3f8"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.43.0+0"

[[deps.gperf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3516a5630f741c9eecb3720b1ec9d8edc3ecc033"
uuid = "1a1c6b14-54f6-533d-8383-74cd7377aa70"
version = "3.1.1+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+1"

[[deps.libevdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "141fe65dc3efabb0b1d5ba74e91f6ad26f84cc22"
uuid = "2db6ffa8-e38f-5e21-84af-90c45d0032cc"
version = "1.11.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libinput_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "eudev_jll", "libevdev_jll", "mtdev_jll"]
git-tree-sha1 = "ad50e5b90f222cfe78aa3d5183a20a12de1322ce"
uuid = "36db933b-70db-51c0-b978-0f229ee0e533"
version = "1.18.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d7015d2e18a5fd9a4f47de711837e980519781a4"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.43+1"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.mtdev_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "814e154bdb7be91d78b6802843f76b6ece642f11"
uuid = "009596ad-96f7-51b1-9f1b-5ce2d5e8a71e"
version = "1.1.6+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.52.0+1"

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
# ╠═90756137-094d-4a22-93a1-a2efdfe8beae
# ╠═c64dc097-1d61-45db-94ce-2cb4456cbdb7
# ╠═57ed207c-b572-4688-b2ef-1e3c574fcea0
# ╠═be482a65-b8f9-48b3-aba8-ff2572e3c7ca
# ╠═ffd99df2-d429-4355-ae71-cfc2906f72d3
# ╠═45d98b5a-d248-41cd-9c5c-e792444dd7d9
# ╟─8147ea5b-1853-49bb-952d-231bc81928c5
# ╟─9941ca6b-98be-4ccd-848d-6bc9e2cfd4a2
# ╠═b1733234-0b5a-4868-913f-082737c16584
# ╠═f5d40d5c-69cc-4026-b61d-bf7a212638fa
# ╠═c09d2976-1e1c-44f8-9c4f-4fd7a2ba72b2
# ╠═ccd5f2ec-077d-44a5-a510-27f77058ce73
# ╠═27cfa500-3ea9-4db9-80dc-7b2d8c158b24
# ╠═806b8b3e-ec11-4819-b6d8-c11424e9639a
# ╠═58b836dd-cf22-4d80-a3db-94f2b405874d
# ╠═a4f381c5-cf17-481f-8f42-eb9e41df61a7
# ╠═be6041bc-c7f1-44a8-8ca0-66fd6fdb252a
# ╠═f0d6194c-8019-45d3-94d0-f7bb8fe0dc9d
# ╠═5e535d50-ee08-40b3-8316-136217f96b5f
# ╠═e92f8963-dfd7-4e66-9091-89dde2d09200
# ╠═3fd1d25a-14a4-4e25-a39c-97aa4866711a
# ╠═6dab7b44-9758-4dec-ae4d-b412769ef44f
# ╠═8597ecfd-039b-4df3-85c9-d7ced79779ea
# ╠═9dbd3e3a-f3d9-4c7b-a1c6-56c9048a31fd
# ╠═4471366b-9d99-4d84-b679-a8d8f709089b
# ╠═a1144feb-1264-4429-b019-d2580f1dee8e
# ╠═32bc923c-fb78-4f47-8e3a-c6efae58163c
# ╠═fde815d6-beb9-4114-82a0-01b8d8aadeae
# ╠═8072e15d-d96f-41d7-864d-3dadd5fc97e8
# ╠═0a91f78d-6214-4a51-81fe-2569a647cd7c
# ╠═679425de-c4a5-4ba5-93f9-2124700997d4
# ╠═97119df8-de27-4484-a51e-e70213d4b335
# ╠═791f6424-bebc-4e58-adfc-c8f1ef87d4a2
# ╠═794e96b7-6a8b-414a-b7f6-0341a9cbfbac
# ╠═43eb9d81-f034-4c2c-bd37-619705342497
# ╠═4147ceaf-0a1a-48e4-9d5c-436d1f5ce146
# ╠═5a5a9af4-e999-4006-b5fc-7b2ad069a910
# ╠═277bef7f-964b-4073-8cbc-e098c5541843
# ╠═ccec6027-9f9d-44d1-9e91-f5f74a188acb
# ╠═96d787aa-3961-4146-b06c-bfaf1ed573d5
# ╠═4ddcfcb2-64bb-4415-b2a3-8bcb4f39acea
# ╠═f75d2093-821b-4d3e-9b94-7ff77240176a
# ╠═c96fc5cc-5b3e-4032-9c7e-b43f486242e6
# ╠═85c7d13d-7b34-42d0-a870-be47428c5a15
# ╠═676f183f-fd44-47ce-a53a-b315dbdff5e1
# ╠═e33a498b-395f-4684-ba2c-a39b66b91255
# ╠═1b684dbb-17f9-441f-b54e-371d0bf4af5e
# ╠═6ecb0714-28f3-42ac-a2c3-8a3506f801e6
# ╠═7ef78fb9-040a-4622-90e0-a173a6721b26
# ╠═d3660350-5972-4a04-9991-2afe1d7534c0
# ╠═9d1dd75d-68fa-41e8-9a8b-5014a27061a6
# ╠═beb669bc-d900-4785-89ab-0b1f5f9def46
# ╠═338e2424-1f47-4232-97d5-f80c72c8f162
# ╠═94cdfc4a-c799-4668-928a-0aa265fb4f53
# ╠═7c662cb8-ee2f-4dc2-980f-e538635008df
# ╠═91e82d6a-2f2a-4399-97f6-523e17d9ab77
# ╠═bb520798-7ab9-4e52-8f33-aef9219bcae4
# ╠═79e07adc-3378-484b-8b65-45275741ca5b
# ╠═d28addae-fc36-4822-9ffc-bb831a0ad03d
# ╠═89fc29e9-9932-45c9-ba71-ddea749a3eb1
# ╠═07e6a510-c868-46c6-8d7e-b764ee4858b6
# ╠═fc227622-466f-4e6f-8b10-c9062915704d
# ╠═31a10846-a373-4e38-87e8-7bed82ae8707
# ╠═1f195800-e327-46cf-8bf5-f728756f0132
# ╠═d66a906b-d034-4144-bd4f-d1c3dff7015d
# ╠═9293a32f-4296-4f96-88ac-00ac51c23360
# ╠═04410d55-81c6-4c4d-bef0-5196023b6212
# ╠═9fa94d73-1100-4d7d-b55e-50c39419b331
# ╠═03f31f7c-b6fa-46b3-9785-2b70abbe9dd1
# ╠═012f1b59-ddb2-4906-b5fb-cad11527af97
# ╠═275aeacc-7e7b-45db-9304-006504302192
# ╠═3ceb000e-fa81-47aa-b891-47a172d1cab6
# ╠═5021204a-d75d-4c79-886f-b0b96ad16417
# ╠═438cf6c1-1fdc-46cb-a2e3-40e33c20b2f8
# ╠═3b5a26d5-2d34-45f6-82a8-231e88140ebb
# ╠═77023dd9-fde7-4c05-aa03-d206bbbdb500
# ╠═448d4c51-ae2a-4154-9199-756114f6eecf
# ╠═c061efe3-bbfe-4736-8f97-091ec5088efc
# ╠═be23b9da-4de5-4388-9a64-fedbccaae986
# ╠═4e6264b7-76cf-4593-ae87-50f7a4ca9b6f
# ╠═678a47cb-6d8b-4994-a713-cc8c274f7411
# ╠═a621a173-458f-4872-93f7-4e57e19856b9
# ╠═9bef0f5a-28e5-4074-b9d9-f7e52e452fb6
# ╠═65beeb3d-d0f4-4931-ac20-b7b22be19eb2
# ╠═44783098-f38e-44fe-86e1-946d02f3f9db
# ╠═73c08bc2-0ebe-4f5a-a769-72d41539a6a0
# ╠═0e7f2b1b-4ddd-44e9-9c99-4c9e604eb89a
# ╠═3c5564d4-7be2-4028-bb15-ba0313da6782
# ╠═51067681-8aa3-471d-85df-e78786cec73d
# ╠═d4cbcaba-14e6-44cc-b667-5d9bd1958b14
# ╠═02eeda0b-8d89-44cb-a604-07aa69b010c9
# ╠═55780648-3d5e-449b-94cd-312b5d70dad6
# ╠═73e31e16-bbe9-4c9a-96bb-194c8110deba
# ╠═c1a1c834-c80e-409c-8cab-b2273021bde7
# ╠═b2598a77-4d7b-4878-b555-d1afa47e0eb6
# ╠═e5df33fd-885f-419f-86ca-de7233b901e4
# ╠═95164e3b-60db-4e7f-84ed-61d1b2978ff0
# ╠═97e1d4da-d7ff-43f5-885a-d3e0864bffb1
# ╠═a494c2d9-e049-4fbe-aaa6-202810673ace
# ╠═0eecba9e-0563-4eba-9b2f-679cf1140fb8
# ╠═b1105cc8-bbbc-4aea-ad2f-c12f238e55ac
# ╠═0e079db5-8e99-4e4b-aa15-0f2dc378fb27
# ╠═1acd31f3-b759-454e-aafe-9b36073f5f4f
# ╠═04ea3d54-2a17-42e1-9365-b304e093fff3
# ╠═233e1ae8-5d66-4c1f-89d6-528cdb8d2476
# ╠═a48ce101-c04a-41c2-a2c4-984a16846424
# ╠═265cb418-e0c8-42ac-af58-d89f3c08ee4c
# ╠═15fe0e3d-b7a8-4bb5-9071-f6dfa6e84be2
# ╠═613c00fc-def2-4ac1-9297-c2b1c1616b52
# ╠═f6c7c0dd-eba5-4118-b854-a175ddde0ad5
# ╠═fe449e67-fe7b-4713-a84b-f4a91f0d9380
# ╠═8b56d961-3cca-4431-8d97-c33bd761387c
# ╠═9545b153-02cc-4904-96d9-a02b80fdfa02
# ╠═77e97975-cad6-4c42-9032-692b7ce6bf91
# ╠═3abe0fcf-fc84-4136-b62d-cff0667d0c1b
# ╠═4b709864-06c9-4808-9584-2673489e39ea
# ╠═adfcb4f3-3946-4e12-ad4c-a6fe40fa2e91
# ╠═e792a8f5-ab93-4091-a775-5b26f01330ab
# ╠═a52b6a55-cf23-465b-b7d9-0bb741372d40
# ╟─d89aecb5-5fa1-4d94-b216-52a101c87747
# ╠═c38dc9ee-5cbb-47dd-a14a-cd185b4b4c46
# ╠═f05cec5b-bb78-4e26-b5ea-e3e51c42a793
# ╠═41f0313d-2859-4751-ac3c-773626fd898b
# ╠═9b59ade6-affb-4a20-aacb-c02967c201b0
# ╠═486e7146-4bd2-4465-a562-bd2052c123e7
# ╠═12e79119-c060-4ac4-92e2-9658a1e9d587
# ╠═71ff13f4-75fc-4b9a-95c2-e2d8cd7bfd5e
# ╠═27a37ed3-6f5e-400f-8192-4b937e651151
# ╠═374a5c3c-1034-4676-aa42-5b5917de5f74
# ╠═d6b6a49f-a4d7-473b-9e46-324cd335b80a
# ╠═a4995532-cb86-4c30-bd3d-46b8f6a9253f
# ╠═ef1c6253-944e-4647-aed2-c71df9ec2906
# ╠═9bec6933-dd24-40b5-92a7-ca8956616ddd
# ╠═002ac714-3e07-40fb-83a2-a2f1c59cfc0f
# ╠═9384e567-cc37-425e-928f-9ec8cd8ec8e5
# ╠═14745152-0313-489e-a668-b17cfa7d0cfd
# ╠═00b8fb2f-d32f-4a92-a113-3a5ae91a7069
# ╠═408f1638-3ad5-4502-97db-e045f0845422
# ╠═fe42ac20-c7f2-416b-af21-e4dccbc4f436
# ╠═aad99eb9-7ee2-4beb-b461-ccdc45ba04b9
# ╠═16edfd3e-26e0-47b7-a36c-e4144ca53d38
# ╠═30b9de2d-97e5-4d7c-9042-1018dfc53b3a
# ╠═a61f6f9f-4941-4d3a-aef9-f556df6ff9a8
# ╠═43f08753-8307-4094-b183-5ef7017e3a1e
# ╠═e90c9e4c-5c00-4253-b6b8-ad9c7b749e95
# ╠═b34a1f96-0d66-4031-9a99-20e73780c7c5
# ╠═c57afb19-d62d-4e8c-b2dd-2b176a6280e0
# ╠═30dd6108-a341-423e-91ba-c29a99b37cb7
# ╠═d015e9cf-a420-43eb-a058-b5eac0e10662
# ╠═d359891c-eefd-4e2a-94c7-0d20f35c61f6
# ╠═d4de4418-316d-4976-a5aa-0923346eb0be
# ╠═7f4622a8-f2ea-41bf-a04e-f9f69faec4a3
# ╠═41920919-0df9-42bf-9749-268a3a5906c2
# ╠═7864f790-f9a0-447b-aad5-c56c0f3e1f34
# ╠═96439721-98b1-4246-bdb4-d32dec3857a6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
