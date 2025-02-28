### A Pluto.jl notebook ###
# v0.19.40

using Markdown
using InteractiveUtils

# ╔═╡ d9015225-b635-42ad-ae96-fe7772a031b7
using Pkg, DrWatson

# ╔═╡ b5f71893-a54a-4b2d-824c-27593a8dd781
begin
  using PlutoUI
  TableOfContents()
end

# ╔═╡ 727e041b-fe08-4f7d-ad19-e3c57772c967
begin
	using Optim
	using GLM
	using CSV
	using Random
	using StatsBase
	using DataFrames
	using Dagitty
	using Turing
	using StatsPlots
	using StatisticalRethinking
	using StatisticalRethinkingPlots
	using ParetoSmoothedImportanceSampling
	import ParetoSmoothedImportanceSampling as psis
	import ParetoSmooth
	using Logging
	# DocStringExtensions provides $(SIGNATURES)
	using DocStringExtensions
	#using ProgressBars
	# have to import the student T distribution explicitly, as it is not exported
	import Distributions: IsoTDist
end

# ╔═╡ ac0b951d-5260-40f5-86ba-1664f264ae21
md"# Chap 7 Ulysses' Compass"

# ╔═╡ e869df0a-4005-46f8-a108-dd86e0ab2aac
#    margin-left: 1%;
#    margin-right: 5%;
html"""<style>
main {
	margin: 0 auto;
    max-width: 90%;
	padding-left: max(50px, 1%);
    padding-right: max(253px, 10%);
	# 253px to accomodate TableOfContents(aside=true)
}
"""

# ╔═╡ 733dae80-07da-4ac9-9b58-517c0c2f6250
versioninfo()

# ╔═╡ 283243e9-25a5-49b7-af83-defb59b47a74
md"## link function from StatisticalRethinking.
- The variant that takes a function as input."

# ╔═╡ 1fc989c1-99c9-4e26-9ed1-ef426ced9897
"""
# link

Generalized link function to evaluate callable for all parameters in dataframe over range of x values.

$(SIGNATURES)

## Required arguments
* `dfa::DataFrame`: data frame with parameters
* `rx_to_val::Function`: function of two arguments: row object and x
* `xrange`: sequence of x values to be evaluated on

## Return values
Is the vector, where each entry was calculated on each value from xrange.
Every such entry is a list corresponding each row in the data frame.

## Examples
```jldoctest
julia> using StatisticalRethinking, DataFrames

julia> d = DataFrame(:a => [1,2], :b=>[1,1])
2×2 DataFrame
 Row │ a      b
     │ Int64  Int64
─────┼──────────────
   1 │     1      1
   2 │     2      1

julia> link(d, (r,x) -> r.a+x*r.b, 1:2)
2-element Vector{Vector{Int64}}:
 [2, 3]
 [3, 4]

```
"""
function link(dfa::DataFrame, rx_to_val::Function, xrange)
  [
    rx_to_val.(eachrow(dfa), (x,))
    for x ∈ xrange
  ]
end

# ╔═╡ a9a95df8-797c-4d43-b043-4e6b10fc4246
md"## 7.0 How to display stdout/terminal output in Pluto.jl"

# ╔═╡ 078fdb65-5bd6-4b0d-b672-617f5912480d
begin
	Plots.default(labels=false)
	# Disable the following line first.
	#Logging.disable_logging(Logging.Warn);
end;

# ╔═╡ 7fb1e6fa-1881-44a3-a409-cdb632b8e4e9
md"- The following for-loop displays nothing because the loop returns a nothing object.
- Pluto.jl only displays returned object."

# ╔═╡ f00222ef-b0d3-4464-87ef-6da1adbb54ac
for i in 1:20
    R = i+100
    T = R^2
    md"hello $R and $T"
end

# ╔═╡ c199328f-81af-4e7c-8fa9-fac5fbeedc8a
md"- the following for-loop will return and output the last iteration. but you can run it differently via map(...) do ... end"

# ╔═╡ 72bdf4a7-9563-4495-9f0c-72b43a76e8a8
let
    x =  nothing
    for i in 1:20
        R = i+100
        T = R^2
        # something
        x = md"hello $R and $T"
    end
    x
end

# ╔═╡ 646fc015-eb4f-46e0-b483-1af49c9660bb
md"- Output of every iteration of the for-loop is possible due to map(1:20)"

# ╔═╡ f8682d46-7ee7-4fd2-a64f-c783360572e1
map(1:20) do i
    R = i+100
    T = R^2
    md"hello $R and $T"
end

# ╔═╡ 4ace5da6-a36e-4d92-856d-2409238ccaa1
macro with_stdout(expr)
        escaped_expr = esc(expr)
	return quote
		stdout_bk = stdout
		rd, wr = redirect_stdout()
		result = ($escaped_expr)
		redirect_stdout(stdout_bk)
		close(wr)
		print_result = read(rd, String) |> Text
		(result, print_result)
	end
end

# ╔═╡ 41e60936-8367-4b04-9bb8-df9fb517a51f
@with_stdout println("I am");

# ╔═╡ 195af951-1ed0-420c-a939-e7883f8fd618
md"After some tinkering (enable Logging.Warn), terminal output is now displayed in Pluto.jl"

# ╔═╡ 93e9248c-2c0b-474c-aa9f-e9c66dcb6a00
@time println("I am");

# ╔═╡ 4c26c5a1-55e2-4007-9085-96ee776e7ebe
macro seeprints(expr)
	quote
		stdout_bk = stdout
		rd, wr = redirect_stdout()
		$expr
		redirect_stdout(stdout_bk)
		close(wr)
		read(rd, String) |> Text
	end
end

# ╔═╡ ee759da7-cc6d-4fd2-8630-e29b323027c4
@seeprints println("I am");

# ╔═╡ 5141dfdf-490d-479e-ac58-63c929ae8fd1
md"## 7.1 The problem with parameters."

# ╔═╡ 611c3828-f01f-4721-830b-736b28620e7e
md"### 7.1 Load data & 7.2 Rescale data"

# ╔═╡ ad511be2-fd88-4aba-a830-21e242d994f1
begin
	sppnames = ["afarensis", "africanus", "habilis", "boisei", "rudolfensis", "ergaster", "sapiens"]
	brainvolcc = [438, 452, 612, 521, 752, 871, 1350]
	masskg = [37.0, 35.5, 34.5, 41.5, 55.5, 61.0, 53.5]
	d = DataFrame(:species => sppnames, :brain => brainvolcc, :mass => masskg)
	d[!,:mass_std] = (d.mass .- mean(d.mass))./std(d.mass)
	d[!,:brain_std] = d.brain ./ maximum(d.brain)
	d
end;

# ╔═╡ 5a2f79ca-2d3e-4cd4-9de9-7c7e283a5052
md"### 7.3 Regress brain on mass，optimized via MAP

To match results from the book, the model was optimized using MAP estimation, not the MCMC I used before. The reason for that is the MCMC producing different estimation for log_σ value, which makes all the values very different.

If you want, you can experiment with NUTS sampler for models in 7.1 and 7.2.

In addition, you can also check [this discussion](https://github.com/StatisticalRethinkingJulia/StatisticalRethinkingTuring.jl/issues/7)"

# ╔═╡ 94b5539b-4374-40b8-9501-8d3df49f20c3
@model function model_m7_1(mass_std, brain_std)
    a ~ Normal(0.5, 1)
    b ~ Normal(0, 10)
    μ = @. a + b*mass_std
    log_σ ~ Normal()
    brain_std ~ MvNormal(μ, exp(log_σ))
end

# ╔═╡ c47284e8-7686-49c8-8d10-2a8460f673cd
begin
	@time m7_1_ch = sample(model_m7_1(d.mass_std, d.brain_std), NUTS(), 1000)
	m7_1 = DataFrame(m7_1_ch)
	@time describe(m7_1)
end


# ╔═╡ ed2f98b3-34bf-4ce5-9ef7-ef3a5499e8ff
size(m7_1)

# ╔═╡ 6c96a6c6-df1d-4dda-8d1d-49b7d13314c4
@df DataFrame(m7_1) corrplot(cols(1:3), seriestype=:scatter, ms=0.2, alpha=0.5, size=(950, 800), bins=30, grid=true)

# ╔═╡ 7994aea2-7b06-47cc-86f2-6afcda5a1707
md"### Checking the m7_1 Chains"

# ╔═╡ 0479f514-1b96-4115-beaa-35a96c40a1d7
m7_1_ch

# ╔═╡ 9a1a6b7f-8810-4a14-910a-2ff422de4289
typeof(m7_1_ch)

# ╔═╡ 788ea3c8-d94d-4201-b860-3f085f18f9e2
m7_1_ch.info

# ╔═╡ 3914cc70-e0c2-4b91-a456-5a301597e0fe
begin
	@show m7_1_ch.name_map
	m7_1_ch.value
end

# ╔═╡ 1efdafc3-497f-434e-9a16-97636a4cfc4b
histogram(m7_1_ch[:log_density])

# ╔═╡ 5868fb4a-eb92-46c4-a753-6e9459b0a006
histogram(m7_1_ch[:acceptance_rate])

# ╔═╡ 358b7b46-129a-464d-86f0-2a1a8da10f3d
histogram(m7_1_ch[:hamiltonian_energy])

# ╔═╡ 8ddad81f-78fd-4a48-953c-d3480d6a3466
histogram(m7_1_ch[:hamiltonian_energy_error])

# ╔═╡ e64277de-23c5-4ec9-ba57-ce39a39add2a
histogram(m7_1_ch[:max_hamiltonian_energy_error])

# ╔═╡ 485d49f2-e36b-4a22-aecb-84a51b8075e5
m7_1_ch[:nom_step_size]

# ╔═╡ 45122674-c5d2-4f61-af03-c74482618e90
md"### Code 7.4 OLS to obtain posterior distribution of a & b, but not $\sigma$"

# ╔═╡ 3b7ca48f-078f-4eef-9d0c-fa8724e711d3
X = hcat(ones(length(d.mass_std)), d.mass_std)

# ╔═╡ 40c173f3-3dbb-4907-9188-632d34b3d7cf
m = lm(X, d.brain_std)

# ╔═╡ 39dc811c-2742-4977-a203-c9fdcb5b218d
md"### Code 7.5 calculate $R^2$"

# ╔═╡ 85bb82da-efe7-4b34-8af5-cf60ae6e4757
Random.seed!(12);

# ╔═╡ 53806285-ea68-4f5c-b3fb-a382a894ec56
md"## Do explicit simulation due to log_σ.

- Why?"

# ╔═╡ 59b9a24b-6967-418b-a4f8-e67ceb0a5474
@time begin
	# d.mass_std is a 7-element vector.
	s = [
		rand(MvNormal((@. r.a + r.b * d.mass_std), exp(r.log_σ)))
		for r ∈ eachrow(m7_1)
	]
	# s is a vector of length 1000. each element is a 7-element vertical vector.
	@show size(s)
	# transpose each element of s to horizontal vector and then vertically concatenate them.
	s = vcat(s'...);
	@show size(s)

	r = mean.(eachcol(s)) .- d.brain_std;
	@show size(r)
	@show resid_var = var(r, corrected=false)
	outcome_var = var(d.brain_std, corrected=false)
	@show outcome_var
	1 - resid_var/outcome_var
end

# ╔═╡ 74b85675-515a-4168-9739-8e8eeb42dab1
@which simulate(m7_1, (r, x) -> Normal(r.a + r.b * x, exp(r.log_σ)), d.mass_std)

# ╔═╡ f4d22dcc-81e8-4279-9eb3-861f0eeb5f83
MvNormal([1,2,3], 0.1)

# ╔═╡ ed541621-2245-49f9-9672-31e20b9b7765
md"### Code 7.6 Why $R^2$ is bad?"

# ╔═╡ 47d9566c-93ec-4f70-b7b6-5586193bcdef
md"#### Function is implemented in a generic way to support any amount of b[x] coefficients."

# ╔═╡ 1e5a39c0-6b5b-4d29-826e-e68c31c8f34e
function R2_is_bad(df; sigma=missing)
    degree = ncol(df[!,r"b"])
    # build mass_std*degree matrix, with each col exponentiated to col's index
    t = repeat(d.mass_std, 1, degree)
    t = hcat(map(.^, eachcol(t), 1:degree)...)
    s = [
        begin
            # calculate product on coefficient's vector
            b = collect(r[r"b"])
            μ = r.a .+ t * b
            s = ismissing(sigma) ? exp(r.log_σ) : sigma
            rand(MvNormal(μ, s))
        end
        for r ∈ eachrow(df)
    ]
    s = vcat(s'...);

    r = mean.(eachcol(s)) .- d.brain_std;
    v1 = var(r, corrected=false)
    v2 = var(d.brain_std, corrected=false)
    1 - v1 / v2
end

# ╔═╡ e8f6166f-20e5-40a2-a8fc-692ea8704b6d
md"### Code 7.7 2nd-degree polynomial"

# ╔═╡ f74d5bc3-747b-4b12-9fb2-7e4a19cfe2c1
@model function model_m7_2(mass_std, brain_std)
    a ~ Normal(0.5, 1)
    b ~ MvNormal([0, 0], 10)
    μ = @. a + b[1]*mass_std + b[2]*mass_std^2
    log_σ ~ Normal()
    brain_std ~ MvNormal(μ, exp(log_σ))
end

# ╔═╡ fa9522ce-d91d-4cbd-9a1a-fe63fd2b7d15
begin
	@time m7_2_ch = sample(model_m7_2(d.mass_std, d.brain_std), NUTS(), 10000)
	@time m7_2 = DataFrame(m7_2_ch)
	@time describe(m7_2)
end

# ╔═╡ 41fc983a-9209-4ff5-b9fa-5798c7d387af
md"### Code 7.8 3-, 4-, 5-degree polynomial fitting: `brain_std ~ mass_std`"

# ╔═╡ 0f8d2476-7379-4bec-8a6f-e6ef81066ebb
md"#### Implemented the sample in a general way."

# ╔═╡ 4632e385-2417-4683-9e31-72825cf5501c
@model function model_m7_n(mass_std, brain_std; degree::Int)
    a ~ Normal(0.5, 1)
    b ~ MvNormal(zeros(degree), 10)
    # build matrix n*degree
    t = repeat(mass_std, 1, degree)
    # exponent its columns
    t = hcat(map(.^, eachcol(t), 1:degree)...)
    # calculate product on coefficient's vector
    μ = a .+ t * b
    
    log_σ ~ Normal()
    brain_std ~ MvNormal(μ, exp(log_σ))
end

# ╔═╡ bf763ccd-2c72-4529-b6ac-747f39f1b9cf
begin
	@time m7_3_ch = sample(model_m7_n(d.mass_std, d.brain_std, degree=3), NUTS(), 1000)
	@time m7_3 = DataFrame(m7_3_ch)
	describe(m7_3)
end

# ╔═╡ 9aa0386d-6b6d-4892-b412-a8e28c0823d8
parentmodule(describe)

# ╔═╡ ef2e821a-d947-40e1-9855-79819aec5dbb
begin
	@time m7_4_ch = sample(model_m7_n(d.mass_std, d.brain_std, degree=4), NUTS(), 1000)
	@time m7_4 = DataFrame(m7_4_ch)
	describe(m7_4)
end

# ╔═╡ e1e48fb9-bb0f-4fe6-a34e-46ea2ced2510
begin
	m7_5_ch = sample(model_m7_n(d.mass_std, d.brain_std, degree=5), NUTS(), 1000)
	m7_5 = DataFrame(m7_5_ch)
	describe(m7_5)
end

# ╔═╡ e259cf96-eb70-4fe7-9c25-1f25686b1faa
md"### Code 7.9: 6-degree polynomial"

# ╔═╡ bff2a56e-e799-4d50-b97b-79983df86565
@model function model_m7_6(mass_std, brain_std)
    a ~ Normal(0.5, 1)
    b ~ MvNormal(zeros(6), 10)
    μ = @. a + b[1]*mass_std + b[2]*mass_std^2 + b[3]*mass_std^3 + 
               b[4]*mass_std^4 + b[5]*mass_std^5 + b[6]*mass_std^6 
    brain_std ~ MvNormal(μ, 0.001)
end

# ╔═╡ 5c26fd02-6695-4f3d-8f17-37c9b2ada2e6
begin
	m7_6_ch = sample(model_m7_6(d.mass_std, d.brain_std), NUTS(), 1000)
	m7_6 = DataFrame(m7_6_ch)
	describe(m7_6)
end

# ╔═╡ 941248e9-c1ec-4d6a-8a2a-dbdd9aee17d8
md"### Code 7.10 Fig 7.3"

# ╔═╡ 97a58b2a-a200-4249-acf3-c52d28ca6aea
mass_seq = range(extrema(d.mass_std)...; length=100)

# ╔═╡ 7174161a-6536-4ec7-a89e-2c385de7052c
begin
	l = [
    	@. r.a + r.b * mass_seq
    	for r ∈ eachrow(m7_1)
	]
	l = vcat(l'...)
	μ = mean.(eachcol(l))
end

# ╔═╡ f4955154-ea66-4523-aacd-1a4beef6d41b
begin
	ci = PI.(eachcol(l))
	ci = vcat(ci'...)
end

# ╔═╡ caa5e742-7606-43fa-8ae3-a1287ff24951
scatter(d.mass_std, d.brain_std; title="1: R² = $(round(R2_is_bad(m7_1); digits=3))")

# ╔═╡ 2f524064-abcc-40a1-a21e-99a0a4636545
plot!(mass_seq, [μ μ]; fillrange=ci, c=:black, fillalpha=0.3)

# ╔═╡ 0f92b3fa-1b99-45f4-8a8e-5b7ea33a464d
md"### Re-implemented the brain_plot function to check my results."

# ╔═╡ cb2d9bdf-3cf3-48f2-a984-5440dba08ad9
function brain_plot(df; sigma=missing)
    degree = ncol(df[!,r"b"])
    # build mass_seq*degree matrix, with each col exponentiated to col's index
    t = repeat(mass_seq, 1, degree)
    t = hcat(map(.^, eachcol(t), 1:degree)...)
    l = [
        r.a .+ t * collect(r[r"b"])
        for r ∈ eachrow(df)
    ]
    l = vcat(l'...)
    μ = mean.(eachcol(l))
    ci = PI.(eachcol(l))
    ci = vcat(ci'...)

    r2 = round(R2_is_bad(df, sigma=sigma); digits=3)
    scatter(d.mass_std, d.brain_std; title="$degree: R² = $r2")
    plot!(mass_seq, [μ μ]; fillrange=ci, c=:black, fillalpha=0.3)
end;

# ╔═╡ 29f7fc44-1d5c-4912-a0b0-07a7e97cfe26
plot(
    brain_plot(m7_1),
    brain_plot(m7_2),
    brain_plot(m7_3),
    brain_plot(m7_4),
    brain_plot(m7_5),
    brain_plot(m7_6, sigma=0.001);
    size=(1000, 600)
)

# ╔═╡ bb21db38-31cf-4e88-86d2-922d62533769
md"### 7.11"

# ╔═╡ 4f7bfda2-297d-432d-83c9-c931f5f62868
i = 3;

# ╔═╡ 90d5c3e8-a045-4d96-aebc-2ec99609e10b
d_minus_i = d[setdiff(1:end,i),:];

# ╔═╡ 3babf620-dd01-45ae-b21c-e46e136057f6
function brain_loo_plot(model, data; title::String)
    (a, b) = extrema(data.brain_std)
    p = scatter(data.mass_std, data.brain_std; title=title, ylim=(a-0.1, b+0.1))
    mass_seq = range(extrema(data.mass_std)...; length=100)
    
    for i ∈ 1:nrow(data)
        d_minus_i = data[setdiff(1:end,i),:]
        df = DataFrame(sample(
				model(d_minus_i.mass_std, d_minus_i.brain_std), 
				NUTS(), 
				1000))

        degree = ncol(df[!,r"b"])
		
        # build mass_seq*degree matrix, with each col exponentiated to col's index
		
        t = repeat(mass_seq, 1, degree)
        t = hcat(map(.^, eachcol(t), 1:degree)...)
        l = [
            r.a .+ t * collect(r[r"b"])
            for r ∈ eachrow(df)
        ]
        l = vcat(l'...)
        μ = mean.(eachcol(l))
        plot!(mass_seq, μ; c=:black)
    end
    p
end

# ╔═╡ 9a5d927d-e816-4f5f-a460-c89a507ce1ae
model_m7_4 = (mass, brain) -> model_m7_n(mass, brain, degree=4)

# ╔═╡ b3778ab5-03b7-4ba5-9501-3e6bb643e4d5
plot(
    brain_loo_plot(model_m7_1, d, title="m7.1"),
    brain_loo_plot(model_m7_4, d, title="m7.4");
    size=(800, 400)
)

# ╔═╡ b55cffd3-d5ce-41db-968d-0b54b1b872a7
md"## 7.2 Entropy and accuracy."

# ╔═╡ e8765238-eec6-41c0-9c8c-148c9e51aad9
md"### 7.12  Information and KL Divergence"

# ╔═╡ fd1f8ae2-6839-4f7e-9141-66824490df72
p = [0.3, 0.7];

# ╔═╡ 3a3537ec-039a-434d-a7d4-15ab41eb97d8
function calc_entropy_given_p(p)
	-sum(p .* log.(p))
end

# ╔═╡ fd90af56-427c-47a6-aa01-ef7ee6399a40
@time calc_entropy_given_p(p)

# ╔═╡ 421a7308-637f-4e55-969d-3afa26cbfc6c
function plot_entropy_for_binomial_varying_p()
	let p0_vec = 0:0.01:1;
		entropy_vec = similar(p0_vec);
		for i ∈ 1:length(p0_vec)
			entropy_vec[i] = calc_entropy_given_p([p0_vec[i], 1-p0_vec[i]])
		end
		scatter(p0_vec, entropy_vec; title="Entropy for a binomial(p)", xlabel="p");
	end
end

# ╔═╡ 0caec6f7-af0d-4d89-b682-763c1e14af93
@time plot_entropy_for_binomial_varying_p()

# ╔═╡ 63ca60f4-f5c6-4928-86bb-f6d131654bc4
@time plot_entropy_for_binomial_varying_p()

# ╔═╡ adb89664-66d8-4dbb-8f42-6043dcc09109
plot_entropy_for_binomial_varying_p()

# ╔═╡ fda881bd-9075-41be-b59d-b930f5444095
md"### 7.13 lppd: Log-Pointwise-Predictive-Density"

# ╔═╡ 9904cc2f-02f1-44d7-9831-fcefe95fe71d
lppd(m7_1, (r,x)->Normal(r.a + r.b*x, exp(r.log_σ)), d.mass_std, d.brain_std)

# ╔═╡ 662b087b-b302-4ecb-95a9-cd696a74fcbc
 md"### 7.14 Run lppd manually"

# ╔═╡ a09a81fb-580d-45d5-9893-121a22a3555f
[
    begin
        s = [
            logpdf(Normal(r.a + r.b * x, exp(r.log_σ)), y)
            for r ∈ eachrow(m7_1)
        ]
		# average log likelihood: log(Σᵢ expᵢ^s/n)
		# average all n samplings. i is sample i.
        logsumexp(s) - log(length(s))
    end
    for (x, y) ∈ zip(d.mass_std, d.brain_std)
]

# ╔═╡ d3389c26-f9dd-4349-8d0b-4f3f9bb93b91
md"### 7.15 lppd function"

# ╔═╡ f17ea741-c98f-4c88-94d2-03a3ca0d08fe
# it could be implemented in a generic way, but I'm too lazy
df_funcs = [
    (m7_1, (r, x) -> Normal(r.a + r.b*x, exp(r.log_σ))),
    (m7_2, (r, x) -> Normal(r.a + r."b[1]" * x + r."b[2]"*x^2, exp(r.log_σ))),
    (m7_3, (r, x) -> Normal(r.a + r."b[1]" * x + r."b[2]"*x^2 + r."b[3]"*x^3, exp(r.log_σ))),
    (m7_4, (r, x) -> Normal(r.a + r."b[1]" * x + r."b[2]"*x^2 + r."b[3]"*x^3 + 
                                  r."b[4]"*x^4, exp(r.log_σ))),
    (m7_5, (r, x) -> Normal(r.a + r."b[1]" * x + r."b[2]"*x^2 + r."b[3]"*x^3 + 
                                  r."b[4]"*x^4 + r."b[5]"*x^5, exp(r.log_σ))),
    (m7_6, (r, x) -> Normal(r.a + r."b[1]" * x + r."b[2]"*x^2 + r."b[3]"*x^3 + 
                                  r."b[4]"*x^4 + r."b[5]"*x^5 + r."b[6]"*x^6, 0.001)),
];

# ╔═╡ 640bc9cb-0967-4a18-8e1d-5a3ed4a9b33c
[
    sum(lppd(df, f, d.mass_std, d.brain_std))
    for (df, f) ∈ df_funcs
]

# ╔═╡ 9ae21be4-07ce-4ac9-ab58-4637ffd2281e
md"### 7.16 Define multiple functions"

# ╔═╡ 78449377-ffcd-41da-8466-d2059c3d406a
@model function m7_sim(x, y; degree::Int=2)
    beta ~ MvNormal(zeros(degree), 1)
    μ = x * beta
    y ~ MvNormal(μ, 1)
end

# ╔═╡ c10300fb-72a0-4668-8bb4-fa4be69b03c7
"""
- Calculate sum(-2*lppd) from sampled params (b), an x matrix and target y values.

$(SIGNATURES) 
- call SR.lppd() function.


- Arguments:
  - m_df: data frame of model coefficients.
  - xseq: a matrix of x, each row is one sample.
 - yseq: a vector of response variable y.

- Returned values
  - lppd of all samples.

"""
function get_lppd(m_df, xseq, yseq)
    t = DataFrame(:b => collect(eachrow(Matrix(m_df))))
    -2*sum(StatisticalRethinking.lppd(t, (r, x) -> Normal(r.b'*x, 1), eachrow(xseq), yseq))
end

# ╔═╡ 1e502519-f1ed-4c83-ba8d-d96e66269d4e
"""
$(SIGNATURES)
"""
function calc_train_test(N, k; count=100)
    trn_v, tst_v = [], []
    for _ in 1:count
        # method sim_train_test from StatisticalRethinking just simulates the data to be fitted by the model
        y, x_train, x_test = sim_train_test(N=N, K=k)

        estim = optimize(m7_sim(x_train, y, degree=max(2,k)), MAP())
        m7_2 = DataFrame(sample(estim, 1000))
        # commented out is the MCMC way of estimation instead of MAP
#         m_chain = sample(m7_sim(x_train, y, degree=max(2,k)), NUTS(), 1000)
#         m7_2 = DataFrame(m_chain)
        t1 = get_lppd(m7_2, x_train, y)
        t2 = get_lppd(m7_2, x_test, y)
        push!(trn_v, t1)
        push!(tst_v, t2)
    end
    (mean_and_std(trn_v), mean_and_std(tst_v))
end

# ╔═╡ 124a5a18-3a96-4394-9836-aa13266a936e
md"### 7.17 Multi-threading"

# ╔═╡ 823b783e-f114-427e-b4b4-f135eec09d86
begin
	k_count = 5
	k_seq = 1:k_count
	count = 100
	trn_20, tst_20 = [], []
	trn_100, tst_100 = [], []
	
	Threads.@threads for k in k_seq
	    println("Processing $k with N=20...")
	    t1, t2 = calc_train_test(20, k, count=count)
	    push!(trn_20, t1)
	    push!(tst_20, t2)
	    println("Processing $k with N=100...")
	    t1, t2 = calc_train_test(100, k, count=count)
	    push!(trn_100, t1)
	    push!(tst_100, t2)
	end
end

# ╔═╡ 3d481718-a252-4f1c-9db9-289bd659982b
md"### 7.18 Plot the training and testing deviance"

# ╔═╡ c62dcfeb-fdb8-4d5d-a51d-286caddf4e00
begin
	scatter(k_seq, first.(trn_20); yerr=last.(trn_20), label="train", title="N=20")
	scatter!(k_seq .+ .1, first.(tst_20); yerr=last.(tst_20), label="test")
end

# ╔═╡ ab263a84-4612-4459-bf50-78bf0f236e44
begin
	scatter(k_seq, first.(trn_100); yerr=last.(trn_100), label="train", title="N=100")
	scatter!(k_seq .+ .1, first.(tst_100); yerr=last.(tst_100), label="test")
end

# ╔═╡ 8b225437-50c2-40f8-aa10-0e0c1b64fa5b
md"## 7.3 Golem taming: regularization

No code pieces in this section"

# ╔═╡ 410933c5-0353-4060-9879-d08a84bb66df
md"## 7.4 Predicting predictive accuracy"

# ╔═╡ 45d6b219-852b-4941-a09e-2128dfc88939
md"### 7.19 Monte Carlo of a Bayesian Linear Model"

# ╔═╡ f6516e63-a3f0-4bcb-a8ee-579ca95a95c3
d_cars = DataFrame(CSV.File("data/cars.csv", drop=["Column1"]))

# ╔═╡ 77c257c8-d4f4-4f33-9038-7f33123c5951
size(d_cars)

# ╔═╡ fe4d08db-f84f-44ae-8499-5ef349e5806f
describe(d_cars)

# ╔═╡ fdad6aeb-79c0-4db5-8ac0-15b14444a679
std.(eachcol(d_cars))

# ╔═╡ 9f8aaf9c-8f23-4d90-b235-5d953713546e
begin	
	@model function model_m(speed, dist)
	    a ~ Normal(0, 100)
	    b ~ Normal(0, 10)
	    μ = @. a + b * speed 
	    σ ~ Exponential(1)
	    dist ~ MvNormal(μ, σ)
	end
	
	Random.seed!(17)
	@time m_cars_ch = sample(model_m(d_cars.speed, d_cars.dist), NUTS(), 1000)
	m_cars_df = DataFrame(m_cars_ch);
end

# ╔═╡ c41a1a22-36e7-46c8-88a7-04c8283fe681
describe(m_cars_df)

# ╔═╡ bc123b91-16a7-47c1-b4ed-241412065d27
std.(eachcol(m_cars_df))

# ╔═╡ aa3e88f8-5802-48f8-b4dc-a0655ad38ffb
md"### 7.20 logprob"

# ╔═╡ 41138aaa-52fb-467c-89a4-37edc46f170e
begin
	fun = (r, (x, y)) -> normlogpdf(r.a + r.b * x, r.σ, y)
	@time lp = StatisticalRethinking.link(m_cars_df, fun, zip(d_cars.speed, d_cars.dist))
	lp = hcat(lp...);
end

# ╔═╡ aed57454-46c0-4abe-b0f7-8b03b8a78d48
md"### 7.21 lppd"

# ╔═╡ b8543e08-fb9d-442d-b3c3-93710660bb54
begin
	n_samples, n_cases = size(lp)
	lppd_vals = [
	    logsumexp(c) - log(n_samples)
	    for c in eachcol(lp)
	];
	
	## if only lppd were needed, we can calculate it with
	# lppd_vals = lppd(m_df, (r, x) -> Normal(r.a + r.b * x, r.σ), d.speed, d.dist)
end

# ╔═╡ 7a2a581a-65a4-4d1f-96a0-03621d8694f0
md"### 7.22 penalty of WAIC"

# ╔═╡ 0bcd703f-3f33-471e-9a9f-e0fafcbb14ea
pWAIC = [
    StatisticalRethinking.var2(c)
    for c in eachcol(lp)
]

# ╔═╡ ded8c2cc-498f-4717-89f1-73b1ad8bef16
md"### 7.23 WAIC"

# ╔═╡ 07e15ebd-d4c3-4960-9af7-59eff42cdd05
-2*(sum(lppd_vals) - sum(pWAIC))

# ╔═╡ e48c366c-ed2b-4005-9d0b-aa77d7bae51d
md"### 7.24 stddev of WAIC"

# ╔═╡ 31774687-7bbb-4474-affe-7aa0e6d6635f
begin
	waic_vec = -2 * (lppd_vals .- pWAIC)
	sqrt(n_cases * StatisticalRethinking.var2(waic_vec))
end

# ╔═╡ 55069810-e31b-43bf-9af4-cb4d4594f788
md"## 7.5 Model comparison

- Data and models from chapter 6"

# ╔═╡ 1bf4d82f-f083-45b1-89b8-b14b3cfde07a
begin
	begin
		Random.seed!(70)
		# number of plants
		N = 100
		h0 = rand(Normal(10, 2), N)
		treatment = repeat(0:1, inner=div(N, 2))
		fungus = [rand(Binomial(1, 0.5 - treat*0.4)) for treat in treatment]
		h1 = h0 .+ rand(MvNormal(5 .- 3 .* fungus, 1))
		
		d_fungus = DataFrame(:h0 => h0, :h1 => h1, :treatment => treatment, :fungus => fungus)
		
		@model function model_m6_6(h0, h1)
		    p ~ LogNormal(0, 0.25)
		    σ ~ Exponential(1)
		    μ = h0 .* p
		    h1 ~ MvNormal(μ, σ)
		end
		
		@time m6_6 = sample(model_m6_6(d_fungus.h0, d_fungus.h1), NUTS(), 1000)
		m6_6_df = DataFrame(m6_6)
		
		@model function model_m6_7(h0, treatment, fungus, h1)
		    a ~ LogNormal(0, 0.2)
		    bt ~ Normal(0, 0.5)
		    bf ~ Normal(0, 0.5)
		    σ ~ Exponential(1)
		    p = @. a + bt*treatment + bf*fungus
		    μ = h0 .* p
		    h1 ~ MvNormal(μ, σ)
		end
		
		@time m6_7 = sample(model_m6_7(d_fungus.h0, d_fungus.treatment, d_fungus.fungus, d_fungus.h1), NUTS(), 1000)
		m6_7_df = DataFrame(m6_7)
		
		@model function model_m6_8(h0, treatment, h1)
		    a ~ LogNormal(0, 0.2)
		    bt ~ Normal(0, 0.5)
		    σ ~ Exponential(1)
		    p = @. a + bt*treatment
		    μ = h0 .* p
		    h1 ~ MvNormal(μ, σ)
		end
		
		@time m6_8 = sample(model_m6_8(d_fungus.h0, d_fungus.treatment, d_fungus.h1), NUTS(), 1000)
		m6_8_df = DataFrame(m6_8);
	end
end

# ╔═╡ f49b25b8-06d0-4f11-948d-b12e74ea665d
md"### 7.25 WAIC for m6_7 (include both treatment and fungus)"

# ╔═╡ 73baf70d-c5b3-4104-9075-f1376858143b
begin
	@time calc_normlogpdf = (r, (x,bt,bf,y)) -> normlogpdf(x*(r.a + r.bt*bt + r.bf*bf), r.σ, y)
	
	# log likelihood calculation
	@time ll = StatisticalRethinking.link(m6_7_df, calc_normlogpdf, 
		zip(d_fungus.h0, d_fungus.treatment, d_fungus.fungus, d_fungus.h1));
	ll = hcat(ll...);
	@show size(ll)
	@time psis.waic(ll)
end

# ╔═╡ cec77f99-48ea-4a81-9a72-bcff3574bf12
md"### 7.26 Compare WAIC of m6.6 - m6.8"

# ╔═╡ bcb4b829-939c-48ac-96a3-7b6d53367c7f
begin
	calc_normlogpdf_1 = (r, (x,y)) -> normlogpdf(x*r.p, r.σ, y)
	m6_ll = StatisticalRethinking.link(m6_6_df, calc_normlogpdf_1, zip(d_fungus.h0, d_fungus.h1));
	m6_ll = hcat(m6_ll...);
	
	calc_normlogpdf_3 = (r, (x,bt,bf,y)) -> normlogpdf(x*(r.a + r.bt*bt + r.bf*bf), r.σ, y)
	m7_ll = StatisticalRethinking.link(m6_7_df, calc_normlogpdf_3, zip(d_fungus.h0, d_fungus.treatment, d_fungus.fungus, d_fungus.h1));
	m7_ll = hcat(m7_ll...);
	
	calc_normlogpdf_2 = (r, (x,bt,y)) -> normlogpdf(x*(r.a + r.bt*bt), r.σ, y)
	m8_ll = StatisticalRethinking.link(m6_8_df, calc_normlogpdf_2, zip(d_fungus.h0, d_fungus.treatment, d_fungus.h1));
	m8_ll = hcat(m8_ll...);
	
	compare([m6_ll, m7_ll, m8_ll], :waic, mnames=["m6", "m7", "m8"])
end

# ╔═╡ 47f11b04-e951-4c42-822b-18baa6b34766
md"### 7.27  stddev of WAIC delta between m6.7 and m6.8"

# ╔═╡ 3853f959-3ffe-4f4f-bb9f-5501845f40c9
begin
	waic_m6_7 = waic(m7_ll, pointwise=true).WAIC
	waic_m6_8 = waic(m8_ll, pointwise=true).WAIC
	n = length(waic_m6_7)
	diff_m6_78 = waic_m6_7 - waic_m6_8
	sqrt(n*StatisticalRethinking.var2(diff_m6_78))
end

# ╔═╡ 2f218914-d9e0-45cd-b9fd-89e35bfcdcc9
md"### 7.28 99% confidence interval of dWAIC"

# ╔═╡ 76b82e84-62bc-43e4-8d39-f96ce0e82ca1
 40.0 .+ [-1, 1]*10.4*2.6

# ╔═╡ 5197af99-c495-4193-8b10-58df5a1756a2
md"### 7.29 plot WAIC/deviance of 3 different models"

# ╔═╡ 5f6fd968-7dc7-40f8-918c-7d07a0dbed97
begin
	dw = compare([m6_ll, m7_ll, m8_ll], :waic, mnames=["m6", "m7", "m8"])
	scatter(reverse(dw.WAIC), reverse(dw.models); xerror=reverse(dw.SE))
end

# ╔═╡ d4f685d5-10da-4597-b987-267d47e23c90
md"### 7.30 stddev of WAIC differences between m6.6 and m6.8"

# ╔═╡ 0f333241-27fd-44d5-9499-2329414b5340
begin
	waic_m6_6 = waic(m6_ll, pointwise=true).WAIC
	waic_m6_8_2 = waic(m8_ll, pointwise=true).WAIC
	diff_m6_68 = waic_m6_6 - waic_m6_8_2
	sqrt(n*StatisticalRethinking.var2(diff_m6_68))
end

# ╔═╡ b1b3d896-b1a6-4684-b0d2-3116d7ba76f0
md"### 7.31 stddev of WAIC differences among all models

Current version of `StatisticalRethinking.compare` doesn't calculate pairwise error. You should use above logic to get values not returned in `compare` result."

# ╔═╡ 15a2f5fe-da00-4524-9462-a9b91e9b71d2
md"### 7.32 Fit 3 models of the divorce dataset ( Divorce rate ~ Marriage rate, Age at Marriage) and get the  corresponding pointwise log-likelihood.
- The divorce datasets contain 50 data points/states."

# ╔═╡ 2c51f054-46d1-41c6-8d9d-05e4f9b2fc0d
begin
	Random.seed!(1)
	d_divorce = DataFrame(CSV.File("data/WaffleDivorce.csv"))
	d_divorce[!,:D] = standardize(ZScoreTransform, d_divorce.Divorce)
	d_divorce[!,:M] = standardize(ZScoreTransform, d_divorce.Marriage)
	d_divorce[!,:A] = standardize(ZScoreTransform, d_divorce.MedianAgeMarriage)
	@show size(d_divorce)
	@model function model_m5_1(A, D)
	    σ ~ Exponential(1)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    μ = @. a + bA * A
	    D ~ MvNormal(μ, σ)
	end
	
	@time m5_1 = sample(model_m5_1(d_divorce.A, d_divorce.D), NUTS(), 1000)
	m5_1_df = DataFrame(m5_1)
	
	@model function model_m5_2(M, D)
	    σ ~ Exponential(1)
	    a ~ Normal(0, 0.2)
	    bM ~ Normal(0, 0.5)
	    μ = @. a + bM * M
	    D ~ MvNormal(μ, σ)
	end
	
	@time m5_2 = sample(model_m5_2(d_divorce.M, d_divorce.D), NUTS(), 1000)
	m5_2_df = DataFrame(m5_2);
	
	@model function model_m5_3(A, M, D)
	    σ ~ Exponential(1)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    bM ~ Normal(0, 0.5)
	    μ = @. a + bA * A + bM * M
	    D ~ MvNormal(μ, σ)
	end
	
	@time m5_3 = sample(model_m5_3(d_divorce.A, d_divorce.M, d_divorce.D), NUTS(), 1000)
	m5_3_df = DataFrame(m5_3);
end

# ╔═╡ c09d043f-566b-43c5-bf90-82e14d682a7b
begin
	@time m5_1_ll = StatisticalRethinking.link(m5_1_df, 
		(r, (x,y)) -> StatsFuns.normlogpdf(r.a + r.bA * x, r.σ, y), 
		zip(d_divorce.A, d_divorce.D));
	m5_1_ll = hcat(m5_1_ll...)
	@show size(m5_1_ll)
	
	@time m5_2_ll = StatisticalRethinking.link(m5_2_df, 
		(r, (x,y)) -> StatsFuns.normlogpdf(r.a + r.bM * x, r.σ, y), 
		zip(d_divorce.M, d_divorce.D));
	m5_2_ll = hcat(m5_2_ll...)
	@show size(m5_2_ll)
	
	@time m5_3_ll = StatisticalRethinking.link(m5_3_df, 
		(r, (a,m,y)) -> StatsFuns.normlogpdf(r.a + r.bA * a + r.bM * m, r.σ, y), 
		zip(d_divorce.A, d_divorce.M, d_divorce.D));
	m5_3_ll = hcat(m5_3_ll...);
end

# ╔═╡ 8b3ec669-e0f1-4fbf-a8b9-066fc4faa5d3
describe(m5_3_df)

# ╔═╡ 02b0e6c8-12ba-46ee-a703-7b7f507560d6
std.(eachcol(m5_3_df))

# ╔═╡ d33289fb-ff49-41c5-bf68-0472e92a6800
plot(m5_3)

# ╔═╡ 896b01ce-9e16-42e3-876e-568011faf107
md"### 7.33 Compare 3 models via PSIS: m5_1 is best."

# ╔═╡ 29d5a336-ea7e-4ae7-b001-0d2fef59c85b
compare([m5_1_ll, m5_2_ll, m5_3_ll], :psis, mnames=["m5.1", "m5.2", "m5.3"])

# ╔═╡ b38c9b77-11ea-457e-9e94-aea8601c339f
md"### 7.34 m5_3: Compare pointwise PSIS Pareto k and WAIC penalty"

# ╔═╡ 4b7c2f1f-1bdf-4442-8033-03544a00dd4e
begin
	@show describe(m5_3_df)
	std.(eachcol(m5_3_df))
end

# ╔═╡ 67ef36b0-7244-42ee-a7ad-bbecad0cb567
"""
- reshape data to format of ParetoSmooth.psis_loo function

$(SIGNATURES)

- Arguments
  - ll: a [number-of-samplings X number-of-data-points] matrix of log-likelihoods.

- Returned values:
  - a 3D array: [number-of-data-points X number-of-samples X 1].
"""
function ll_to_psis(ll::Matrix{<:Real})
	@show size(ll)
	t = ll'
	@show size(t)
	#Make the dataset 3 dimensional
	collect(reshape(t, size(t)..., 1))
end

# ╔═╡ 2dacd63f-b12a-461f-8509-ac557744d612
begin
	m5_3_t = ll_to_psis(m5_3_ll)
	@show size(m5_3_t)
	PSIS_m5_3 = ParetoSmooth.psis_loo(m5_3_t)
	WAIC_m5_3 = psis.waic(m5_3_ll, pointwise=true)
end

# ╔═╡ c6535255-66dd-4d99-bd31-19e67f8ba055
PSIS_m5_3

# ╔═╡ 69e5abc8-4e53-4842-8cf2-5fc0bf6b900c
begin
	scatter(PSIS_m5_3.pointwise(:pareto_k), WAIC_m5_3.penalty, 
		    xlab="PSIS Pareto k", ylab="WAIC penalty", title="Gaussian model (m5.3)")
	vline!([0.5], c=:black, s=:dash)
end

# ╔═╡ e2c9ad5f-3130-4927-9d78-c5f416ebcceb
"""
Find outliers with either Pareto K too large or WAIC penalty too large.
$(SIGNATURES)

Returned arguments
- a new dataframe given selected rows
"""
find_outliers(df::DataFrame, pareto_k_vec, waic_penalty_vec::Vector{Float64}; min_pareto_k::Float64=0, min_waic_penalty::Float64=0) = begin
	state_ind_vec = [i for i in 1:length(pareto_k_vec) if pareto_k_vec[i] >= min_pareto_k || waic_penalty_vec[i]>=min_waic_penalty]	
	#new_df = DataFrame(d_divorce[state_ind_vec,:], "ParetoK"=>pareto_k_vec[state_ind_vec], "WAIC_Penalty"=>waic_penalty_vec[state_ind_vec])
	
	# Combine with hcat
	new_df = DataFrames.hcat(df[state_ind_vec,:], pareto_k_vec[state_ind_vec], waic_penalty_vec[state_ind_vec]; makeunique=true)
	# Set column names (optional)
	DataFrames.rename!(new_df, append!(names(df), ["ParetoK", "WAIC_Penalty"]))
	new_df
end

# ╔═╡ d6392293-db93-4be9-8fe5-383e5c1a4188
find_outliers(d_divorce, PSIS_m5_3.pointwise(:pareto_k), WAIC_m5_3.penalty; min_pareto_k=0.4, min_waic_penalty=0.5)

# ╔═╡ 95038f89-670d-4eb0-9f17-c7aca823ae40
md"### 7.34.1 `m5_3_log_σ_normal`: Compare pointwise PSIS Pareto k and WAIC penalty"

# ╔═╡ 64ebf7d0-9715-4a9e-a230-994c6a5c860e
@model function model_m5_3_log_σ(A, M, D)
	log_σ ~ Normal(0, 0.2)
	a ~ Normal(0, 0.2)
	bA ~ Normal(0, 0.5)
	bM ~ Normal(0, 0.5)
	μ = @. a + bA * A + bM * M
	D ~ MvNormal(μ, exp(log_σ))
end

# ╔═╡ dabc23d9-0789-46b7-b4c7-6a57cfc9ede5
begin
	@time m5_3_log_σ = sample(model_m5_3_log_σ(d_divorce.A, d_divorce.M, d_divorce.D), NUTS(), 1_000)
	m5_3_log_σ_df = DataFrame(m5_3_log_σ);
end

# ╔═╡ cbfd99c7-9f83-4d61-93de-0c1c8e751bba
est_summary(mcmc_df; σ_ind=4) = begin
	mcmc_df_sum = describe(mcmc_df)
	println("exp(median(log_σ estimate) ", exp.(mcmc_df_sum[σ_ind, :median]))
	println("σ median est is ", median(exp.(mcmc_df[!, :log_σ])))
	mcmc_df_sum[!, :σ] = std.(eachcol(mcmc_df))
	@show mcmc_df_sum
	"stddev of σ is $(std(exp.(mcmc_df[!,:log_σ])))"
end

# ╔═╡ 640874cb-242b-46b0-856a-3377e6e58c9b
est_summary(m5_3_log_σ_df)

# ╔═╡ 844417a4-b952-415f-872a-197932a8092b
begin
	@time m5_3_log_σ_ll = link(m5_3_log_σ_df, 
		(r, (a,m,d)) -> StatsFuns.normlogpdf(r.a + r.bA * a + r.bM * m, exp(r.log_σ), d), 
		zip(d_divorce.A, d_divorce.M, d_divorce.D));
	m5_3_log_σ_ll = hcat(m5_3_log_σ_ll...);
	@time PSIS_m5_3_log_σ = ParetoSmooth.psis_loo(ll_to_psis(m5_3_log_σ_ll))
	@time WAIC_m5_3_log_σ = psis.waic(m5_3_log_σ_ll, pointwise=true)
end

# ╔═╡ b42814ca-247d-456b-9017-4b84fa146626
size(m5_3_log_σ_ll)

# ╔═╡ efadbcdd-edfe-4535-b683-336a8aab1864
PSIS_m5_3_log_σ

# ╔═╡ 6c0440d4-3073-4d1d-9973-b6c3da09758c
begin
	scatter(PSIS_m5_3_log_σ.pointwise(:pareto_k), WAIC_m5_3_log_σ.penalty, 
		    xlab="PSIS Pareto k", ylab="WAIC penalty", title="Gaussian model (m5.3) with log_σ")
	vline!([0.5], c=:black, s=:dash)
end

# ╔═╡ e9b7616d-a5cb-4eea-9afe-e18d29d858f5
find_outliers(d_divorce, PSIS_m5_3_log_σ.pointwise(:pareto_k), WAIC_m5_3_log_σ.penalty; min_pareto_k=0.4, min_waic_penalty=0.3)

# ╔═╡ 80f475ca-4ed8-4923-865f-f074cbe6117e
@which(names)

# ╔═╡ 59b23c71-f172-4aa5-ad3e-2f1b0876188f
md"### 7.35 m5_3t: MV T-dist df=2, Compare pointwise PSIS Pareto k and WAIC penalty.
- logNormal for σ is way better than Exponential, manifested by pareto_k."

# ╔═╡ 2106ac11-33de-4673-bc1f-32ecb57089f6
begin
	@model function model_m5_3t(A, M, D)
	    #σ ~ Exponential(1)
		# logNormal is way better than Exponential, manifested by pareto_k.
		log_σ ~ Normal(0, 0.3)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    bM ~ Normal(0, 0.5)
	    μ = @. a + bA * A + bM * M
		#z = (D.-μ)/σ
		# The vector . below is optional for NUTS sample. But psis_loo() requires it.
	    #z ~ TDist(2)
		#D ~ Distributions.IsoTDist(2, μ, σ)
		D ~ Distributions.mvtdist(2, μ, exp(log_σ))
	end
	
	@time m5_3t = sample(model_m5_3t(d_divorce.A, d_divorce.M, d_divorce.D), NUTS(), 1000)
	m5_3t_df = DataFrame(m5_3t);
end

# ╔═╡ 048318ba-f836-4cdf-9e73-7a785c736297
est_summary(m5_3t_df)

# ╔═╡ f73d822c-a815-4a35-b0cf-c11c0c30c6ce
plot(m5_3t)

# ╔═╡ 32ecb432-7176-4aa3-9369-b5de15634bdc
ParetoSmooth.psis_loo(model_m5_3t(d_divorce.A, d_divorce.M, d_divorce.D), m5_3t)

# ╔═╡ 7ec1588b-54fb-4803-9e21-2dd9e79ba7c9
begin
	
	m5_3t_ll = StatisticalRethinking.link(m5_3t_df, 
		(r, (a,m,y)) -> Distributions.logpdf(Distributions.mvtdist(2, [r.a + r.bA * a + r.bM * m], exp(r.log_σ)), [y]), 
		zip(d_divorce.A, d_divorce.M, d_divorce.D));
	m5_3t_ll = hcat(m5_3t_ll...);
	
	m5_3t_t = ll_to_psis(m5_3t_ll)
	@show size(m5_3t_t)
	PSIS_m5_3t = ParetoSmooth.psis_loo(m5_3t_t)
	WAIC_m5_3t = psis.waic(m5_3t_ll, pointwise=true)
end

# ╔═╡ 69510bfa-79c0-4bca-87dc-4ec7b8ed94af
PSIS_m5_3t

# ╔═╡ 5792f4ff-f1bd-48bb-968a-0ebc1a3b4c53
PSIS_m5_3t.psis_object

# ╔═╡ 39dbf2e7-13fa-4c21-800e-80d7af55d03e
begin
	@show propertynames(PSIS_m5_3t)
	@show size(PSIS_m5_3t.pointwise)
	@show typeof(PSIS_m5_3t.pointwise)
	@show propertynames(PSIS_m5_3t.pointwise)
	PSIS_m5_3t.pointwise
end

# ╔═╡ 76c05007-037d-48d9-86b7-9f37a799e546
begin
	@show PSIS_m5_3t.pointwise.data
	@show PSIS_m5_3t.pointwise.statistic
end

# ╔═╡ 63eb903d-c425-46a0-8433-c80af6470bb1
#2nd data point (divorce dataset)
PSIS_m5_3t.pointwise[data=2]

# ╔═╡ ff0a1377-9d07-4d88-a06c-38a91a6b12d1
histogram(collect(PSIS_m5_3t.pointwise[statistic=5]), bins=20, title="Histogram of pareto_k")

# ╔═╡ a931dd64-2491-4a11-af2e-0901041bb0be
# this approach does not work.
PSIS_m5_3t.pointwise[statistic=":pareto_k"]

# ╔═╡ b1581df7-c821-483d-a6a9-e446e3245572
PSIS_m5_3t.pointwise(Symbol("pareto_k"))

# ╔═╡ cd4ce03c-84f1-4678-b74d-3e98ed510300
begin
	@show typeof(PSIS_m5_3t.pointwise(:cv_elpd))
	size(PSIS_m5_3t.pointwise(:cv_elpd))
end

# ╔═╡ 4f211432-0c05-4a47-a9ae-01d67a3f6c4a
md"- No outliers in PSIS K after replacing Normal() with student T " 

# ╔═╡ 200694d2-400b-4510-b232-a3e3e8238ae5
begin
		scatter(PSIS_m5_3t.pointwise(:pareto_k), WAIC_m5_3t.penalty, 
		    xlab="PSIS Pareto k", ylab="WAIC penalty", title="Student T (df=2) (m5.3)")
		vline!([0.5], c=:black, s=:dash)
end

# ╔═╡ 8096b9a1-faaf-4bfb-a898-16324ddca400
@time find_outliers(d_divorce, PSIS_m5_3t.pointwise(:pareto_k), WAIC_m5_3t.penalty; min_pareto_k=0.3, min_waic_penalty=0.1)

# ╔═╡ 94b4e89f-cc44-4cbe-b3ea-bfdf2414858e
md"### 7.36 `m5_3t`: 1D T-dist (failed in ForwardDiff but succeeded via using arraydist)"

# ╔═╡ 523ec911-c963-436d-a96f-552c08b5b95a
TDist(μ, σ, ν) = μ + Distributions.TDist(ν)*σ

# ╔═╡ b1c7da74-31f2-47fd-bce1-099dc64545bb
begin
	@model function model_m5_3_singleT(A, M, D)
		no_of_D = length(D)
	    σ ~ Exponential(1)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    bM ~ Normal(0, 0.5)
		μ = similar(A)
		for i in 1:no_of_D
	    	μ[i] = a + bA * A[i] + bM * M[i]
	    	D[i] ~ TDist(μ[i], σ, 2::Int64)
		end
	end
	
	@time m5_3_singleT = sample(model_m5_3_singleT(d_divorce.A, d_divorce.M, d_divorce.D), NUTS(), 1_000);
	m5_3_singleT_df = DataFrame(m5_3_singleT);
end

# ╔═╡ 9dd72017-8504-46f8-b5d0-789bd1ed1d2a
begin
	#tdist_custom(μ) = TDist(μ, σ, 2::Int64)
	#lazyarray(f, x) = LazyArray(Base.broadcasted(f, x))
	@model function model_m5_3_array_singleT(A, M, D)
	    #σ ~ Exponential(1)
		log_σ ~ Normal(0, 0.3)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    bM ~ Normal(0, 0.5)
		μ = @. a + bA * A + bM * M
	    D ~ arraydist(map(x -> TDist(x, exp(log_σ), 2::Int64), μ))
	end
	
	@time m5_3_array_singleT = sample(model_m5_3_array_singleT(d_divorce.A, d_divorce.M, d_divorce.D), NUTS(), 1_000);
	m5_3_array_singleT_df = DataFrame(m5_3_array_singleT);
end

# ╔═╡ ea489813-0478-4e72-98cb-b6ab92f41a4e
est_summary(m5_3_array_singleT_df)

# ╔═╡ 7775c476-4b7e-4373-800d-40dd160177f8
begin
	@time m5_3_array_singleT_ll = StatisticalRethinking.link(m5_3_array_singleT_df, 
		(r, (a,m,d)) -> StatsFuns.normlogpdf(r.a + r.bA * a + r.bM * m, exp(r.log_σ), d), 
		zip(d_divorce.A, d_divorce.M, d_divorce.D));
	m5_3_array_singleT_ll = hcat(m5_3_array_singleT_ll...);
	@time PSIS_m5_3_array_singleT = ParetoSmooth.psis_loo(ll_to_psis(m5_3_array_singleT_ll))
	@time WAIC_m5_3_array_singleT = psis.waic(m5_3_array_singleT_ll, pointwise=true)
end


# ╔═╡ 98f9395b-f436-476b-be03-a9898447894f
begin
	scatter(PSIS_m5_3_array_singleT.pointwise(:pareto_k), WAIC_m5_3_array_singleT.penalty, 
		    xlab="PSIS Pareto k", ylab="WAIC penalty", title="1D T-distribution model (m5.3) with log_σ")
	vline!([0.5], c=:black, s=:dash)
end


# ╔═╡ 99a9860b-34ef-43c4-a817-8ef90f5ffbf6
find_outliers(d_divorce, PSIS_m5_3_array_singleT.pointwise(:pareto_k), WAIC_m5_3_array_singleT.penalty; min_pareto_k=1.0, min_waic_penalty=1.0)

# ╔═╡ 7d1bd042-96a3-4eb9-9942-599c35d3d92b
md"- Many more outliers using 1D T-dist vs 2D T-dist.
- Primary cause: log_σ estimates by 1D T-dist (-.0.45) is much smaller than 2D T-dist (-0.15). But not sure why so different."

# ╔═╡ 7c8d4ad0-215d-4d9f-9034-c7a0c8f6734c
md"### Try truncated cauchy as σ (represented as `log_σ` so that est_summary can be invoked)."

# ╔═╡ d4640e8c-b1cc-4d06-adc8-96193f7b2790
begin
	#tdist_custom(μ) = TDist(μ, σ, 2::Int64)
	#lazyarray(f, x) = LazyArray(Base.broadcasted(f, x))
	@model function model_m5_3_array_singleT_cauchy(A, M, D)
	    #σ ~ Exponential(1)
		log_σ ~ truncated(Cauchy(0, 1), 0, Inf)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    bM ~ Normal(0, 0.5)
		μ = @. a + bA * A + bM * M
	    D ~ arraydist(map(x -> TDist(x, log_σ, 2::Int64), μ))
	end
	
	@time m5_3_array_singleT_cauchy = sample(model_m5_3_array_singleT_cauchy(d_divorce.A, d_divorce.M, d_divorce.D), NUTS(), 1_000);
	m5_3_array_singleT_cauchy_df = DataFrame(m5_3_array_singleT_cauchy);
end

# ╔═╡ 1f440c0e-a202-4a28-95d1-3c71337a2ba7
est_summary(m5_3_array_singleT_cauchy_df)

# ╔═╡ 682fdb58-c13e-48b0-8529-a4cd53bdebb2
md"- σ estimate (0.58) is very similar to the prior σ estimate (0.64).
- Probably as many outliers as before." 

# ╔═╡ 030db799-b6e1-458d-814e-be806dd296dc
md"### 7.37 `m5_1t`: `m5_1` but uses T-distribution"

# ╔═╡ edacad84-bc81-4dc0-94e5-5cd2809bdae2
begin
	@model function model_m5_1t(A, D)
	    a ~ Normal(0, 0.2)
	    bA ~ Normal(0, 0.5)
	    log_σ ~ Normal(0, 0.2)
	    μ = @. a + bA * A
		# The vector . below is optional for NUTS sample. But psis_loo() requires it.
	    D ~ IsoTDist(2, μ, exp(log_σ))
	end
	
	@time m5_1t = sample(model_m5_1t(d_divorce.A, d_divorce.D), NUTS(), 1000)
	m5_1t_df = DataFrame(m5_1t);
end

# ╔═╡ a8caa1df-141f-4665-a864-9ae960682c80
est_summary(m5_1t_df; σ_ind=3)

# ╔═╡ de16bb86-0468-4db3-a085-cf11d437db17
plot(m5_1t)

# ╔═╡ fc186a6d-7afa-43f1-9545-c14399a6d708
begin
	m5_1t_ll = StatisticalRethinking.link(m5_1t_df, 
		(r, (a,d)) -> Distributions.logpdf(IsoTDist(2, [r.a + r.bA * a], exp(r.log_σ)), [d]), 
		zip(d_divorce.A, d_divorce.D));
	m5_1t_ll = hcat(m5_1t_ll...);
	
	m5_1t_t = ll_to_psis(m5_1t_ll)
	@show size(m5_1t_t)
	PSIS_m5_1t = ParetoSmooth.psis_loo(m5_1t_t)
	WAIC_m5_1t = psis.waic(m5_1t_ll, pointwise=true)
end

# ╔═╡ 3c752715-c8e0-473d-b70a-7769fee640e1
begin
		scatter(PSIS_m5_1t.pointwise(:pareto_k), WAIC_m5_1t.penalty, 
		    xlab="PSIS Pareto k", ylab="WAIC penalty", title="Divorce (T df=2)  ~ a + b*Age-at-Marraige (m5.1)")
		vline!([0.5], c=:black, s=:dash)
end

# ╔═╡ 20a3bb3c-04b5-42dd-8013-3f689d782d00
md"- If σ is modelled by Exponential(1), stddev of σ of `m5_1t_t` is much larger than `m5_1` (Normal distribution), which may explain why there are `more Pareto K outliers` in this student T model than Normal.
- But once log_σ ~ Normal(0, 0.2) is used instead, T distribution is better.
- A similar model by PyMC (another notebook) produces a much smaller stddev, thus no Pareto K outlier. Not sure why."

# ╔═╡ 9d52314c-e559-48d6-ad0f-76a4c6f36b67
@time find_outliers(d_divorce, PSIS_m5_1t.pointwise(:pareto_k), WAIC_m5_1t.penalty; min_pareto_k=0.22, min_waic_penalty=0.05)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
Dagitty = "d56128e0-8113-48cd-82a0-fc808dc30d4b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
DocStringExtensions = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
DrWatson = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
GLM = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
Logging = "56ddb016-857b-54e1-b83d-db4d58db5568"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
ParetoSmooth = "a68b5a21-f429-434e-8bfa-46b447300aac"
ParetoSmoothedImportanceSampling = "98f080ec-61e2-11eb-1c7b-31ea1097256f"
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
DocStringExtensions = "~0.9.3"
DrWatson = "~2.13.0"
GLM = "~1.9.0"
Optim = "~1.8.0"
ParetoSmooth = "~0.7.8"
ParetoSmoothedImportanceSampling = "~1.5.3"
PlutoUI = "~0.7.23"
StatisticalRethinking = "~4.7.4"
StatisticalRethinkingPlots = "~1.1.0"
StatsBase = "~0.34.2"
StatsPlots = "~0.15.6"
Turing = "~0.30.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.10.2"
manifest_format = "2.0"
project_hash = "f06b70866ff142c649faf07a932855f150a627f1"

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
git-tree-sha1 = "b0489adc45a7c8cf0d8e2ddf764f89c1c3decebd"
uuid = "80f14c24-f653-4e6a-9b94-39d6b0f70001"
version = "5.2.0"

[[deps.AbstractPPL]]
deps = ["AbstractMCMC", "DensityInterface", "Random", "Setfield"]
git-tree-sha1 = "9774889eac07c2e342e547b5c5c8ae5a2ce5c80b"
uuid = "7a57a42e-76ec-4ea3-a279-07e840d6d9cf"
version = "0.7.1"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "0f748c81756f2e5e6854298f11ad8b2dfae6911a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.0"

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
git-tree-sha1 = "16589dbdd36c782ff01700908e962b303474f641"
uuid = "5b7e9947-ddc0-4b3f-9b55-0d8042f74170"
version = "0.8.1"
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
deps = ["Bijectors", "Distributions", "DistributionsAD", "DocStringExtensions", "ForwardDiff", "LinearAlgebra", "ProgressMeter", "Random", "Requires", "StatsBase", "StatsFuns", "Tracker"]
git-tree-sha1 = "1f919a9c59cf3dfc68b64c22c453a2e356fca473"
uuid = "b5ca4192-6429-45e5-a2d9-87aec30a685c"
version = "0.2.4"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

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
deps = ["Adapt", "LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "44691067188f6bd1b2289552a23e4b7572f4528d"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.9.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
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
deps = ["ArgCheck", "ChainRules", "ChainRulesCore", "ChangesOfVariables", "Compat", "Distributions", "Functors", "InverseFunctions", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "MappedArrays", "Random", "Reexport", "Requires", "Roots", "SparseArrays", "Statistics"]
git-tree-sha1 = "199dc2c4151db557549a0ad8888ce1a60337ff42"
uuid = "76274a88-744f-5084-9051-94815aaf08c4"
version = "0.13.8"

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

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "SparseInverseSubset", "Statistics", "StructArrays", "SuiteSparse"]
git-tree-sha1 = "4e42872be98fa3343c4f8458cbda8c5c6a6fa97c"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.63.0"

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
git-tree-sha1 = "67c1f244b991cad9b0aa4b7540fb758c2488b129"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.24.0"

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
git-tree-sha1 = "c955881e3c981181362ae4088b35995446298b80"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.14.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.0+0"

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
git-tree-sha1 = "0f4b5d62a88d8f59003e43c25a8a90de9eb76317"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.18"

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
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "7c302d7a5fec5214eb8a5a4c466dcf7a51fcf169"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.107"
weakdeps = ["ChainRulesCore", "DensityInterface", "Test"]

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

[[deps.DistributionsAD]]
deps = ["Adapt", "ChainRules", "ChainRulesCore", "Compat", "Distributions", "FillArrays", "LinearAlgebra", "PDMats", "Random", "Requires", "SpecialFunctions", "StaticArrays", "StatsFuns", "ZygoteRules"]
git-tree-sha1 = "060a19f3f879773399a7011676eb273ccc265241"
uuid = "ced4e74d-a319-5a8a-b0ac-84af2272839c"
version = "0.6.54"

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
git-tree-sha1 = "f83dbe0ef99f1cf32b815f0dad632cb25129604e"
uuid = "634d3b9d-ee7a-5ddf-bec9-22491ea816e1"
version = "2.13.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.DynamicPPL]]
deps = ["ADTypes", "AbstractMCMC", "AbstractPPL", "BangBang", "Bijectors", "Compat", "ConstructionBase", "Distributions", "DocStringExtensions", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "MacroTools", "OrderedCollections", "Random", "Requires", "Setfield", "Test"]
git-tree-sha1 = "6fe2424f8f47c0fecd01349a2a77987f3c988393"
uuid = "366bfd00-2699-11ea-058f-f148b4cae6d8"
version = "0.24.9"

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
git-tree-sha1 = "4558ab818dcceaab612d1bb8c19cee87eda2b83c"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.5.0+0"

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
git-tree-sha1 = "bfe82a708416cf00b73a3198db0859c82f741558"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.10.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "bc0c5092d6caaea112d3c8e3b238d61563c58d5f"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.23.0"

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
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

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

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

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

[[deps.GLM]]
deps = ["Distributions", "LinearAlgebra", "Printf", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns", "StatsModels"]
git-tree-sha1 = "273bd1cd30768a2fddfa3fd63bbc746ed7249e5f"
uuid = "38e38edf-8417-5370-95a0-9cbb8c7f171a"
version = "1.9.0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "ec632f177c0d990e64d955ccc1b8c04c485a0950"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.6"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "UUIDs", "p7zip_jll"]
git-tree-sha1 = "3437ade7073682993e092ca570ad68a2aba26983"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.73.3"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "FreeType2_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt6Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a96d5c713e6aa28c242b0d25c1347e258d6541ab"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.73.3+0"

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
git-tree-sha1 = "359a1ba2e320790ddbe4ee8b4d54a305c0ea2aff"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.80.0+0"

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
git-tree-sha1 = "8e59b47b9dc525b70550ca082ce85bcd7f5477cd"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.5"

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
git-tree-sha1 = "8b72179abc660bfab5e28472e019392b97d0985c"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.4"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.Inflate]]
git-tree-sha1 = "ea8031dea4aff6bd41f1df8f2fdfb25b33626381"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.4"

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
git-tree-sha1 = "5fdf2fe6724d8caabf43b557b84ce53f3b7e2f6b"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2024.0.2+0"

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
git-tree-sha1 = "896385798a8d49a255c398bd49162062e4a4c435"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.13"
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
git-tree-sha1 = "3336abae9a713d2210bb57ab484b1e065edd7d23"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.0.2+0"

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
git-tree-sha1 = "fee018a29b60733876eb557804b5b109dd3dd8a7"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.8"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

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
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "50901ebc375ed41dbf8058da26f9de442febbbec"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.1"

[[deps.Latexify]]
deps = ["Format", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Requires"]
git-tree-sha1 = "cad560042a7cc108f5a4c24ea1431a9221f22c1b"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.2"

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
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "f9557a255370125b405568f9767d6d195822a175"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.17.0+0"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dae976433497a2f841baadea93d27e68f1a12a97"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.39.3+0"

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
git-tree-sha1 = "0a04a1318df1bf510beb2562cf90fb0c386f58c4"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.39.3+1"

[[deps.LightGraphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "432428df5f360964040ed60418dd5601ecd240b6"
uuid = "093fc24a-ae57-5d10-9952-331d41423f4d"
version = "1.3.5"

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
git-tree-sha1 = "9c50732cd0f188766b6217ed6a2ebbdaf9890029"
uuid = "996a588d-648d-4e1f-a8f0-a84b347e47b1"
version = "1.7.0"

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

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "72dc3cf284559eb8f53aa593fe62cb33f83ed0c0"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2024.0.0+0"

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

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "d268e82322cc5df142a3664d03d59adecd53abf9"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.27.1"

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
git-tree-sha1 = "2d106538aebe1c165e16d277914e10c550e9d9b7"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.4.2"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NNlib]]
deps = ["Adapt", "Atomix", "ChainRulesCore", "GPUArraysCore", "KernelAbstractions", "LinearAlgebra", "Pkg", "Random", "Requires", "Statistics"]
git-tree-sha1 = "1fa1a14766c60e66ab22e242d45c1857c83a3805"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.9.13"

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
git-tree-sha1 = "0ae91efac93c3859f5c812a24c9468bb9e50b028"
uuid = "86f7a689-2022-50b4-a561-43c23ac3c673"
version = "0.10.1"

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
git-tree-sha1 = "6a731f2b5c03157418a20c12195eb4b74c8f8621"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.13.0"
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
git-tree-sha1 = "af81a32750ebc831ee28bdaaba6e1067decef51e"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.2"

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
git-tree-sha1 = "ffb25abb77780fd8f0bc3ae544ef6de3b917ccd0"
uuid = "a68b5a21-f429-434e-8bfa-46b447300aac"
version = "0.7.8"
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
git-tree-sha1 = "3bdfa4fa528ef21287ef659a89d686e8a1bcb1a9"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.40.3"

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
deps = ["Adapt", "ArrayInterface", "DocStringExtensions", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "SparseArrays", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "d8f131090f2e44b145084928856a561c83f43b27"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "3.13.0"

    [deps.RecursiveArrayTools.extensions]
    RecursiveArrayToolsFastBroadcastExt = "FastBroadcast"
    RecursiveArrayToolsForwardDiffExt = "ForwardDiff"
    RecursiveArrayToolsMeasurementsExt = "Measurements"
    RecursiveArrayToolsMonteCarloMeasurementsExt = "MonteCarloMeasurements"
    RecursiveArrayToolsReverseDiffExt = ["ReverseDiff", "Zygote"]
    RecursiveArrayToolsTrackerExt = "Tracker"
    RecursiveArrayToolsZygoteExt = "Zygote"

    [deps.RecursiveArrayTools.weakdeps]
    FastBroadcast = "7034ab61-46d4-4ed7-9d0f-46aef9175898"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    MonteCarloMeasurements = "0987c9cc-fe09-11e8-30f0-b96dd679fdca"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
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
git-tree-sha1 = "6aacc5eefe8415f47b3e34214c1d79d2674a0ba2"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.12"

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
deps = ["ADTypes", "ArrayInterface", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "PrecompileTools", "Preferences", "Printf", "RecipesBase", "RecursiveArrayTools", "Reexport", "RuntimeGeneratedFunctions", "SciMLOperators", "SciMLStructures", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables"]
git-tree-sha1 = "d15c65e25615272e1b1c5edb1d307484c7942824"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "2.31.0"

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
deps = ["ArrayInterface", "DocStringExtensions", "LinearAlgebra", "MacroTools", "Setfield", "SparseArrays", "StaticArraysCore"]
git-tree-sha1 = "10499f619ef6e890f3f4a38914481cc868689cd5"
uuid = "c0aeaf25-5076-4817-a8d5-81caf7dfa961"
version = "0.3.8"

[[deps.SciMLStructures]]
git-tree-sha1 = "5833c10ce83d690c124beedfe5f621b50b02ba4d"
uuid = "53ae85a6-f571-4167-b2af-e1d143709226"
version = "1.1.0"

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
git-tree-sha1 = "0e7508ff27ba32f26cd459474ca2ede1bc10991f"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.1"

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

[[deps.ShiftedArrays]]
git-tree-sha1 = "503688b59397b3307443af35cd953a13e8005c16"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "2.0.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

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
git-tree-sha1 = "e2cfc4012a19088254b3950b85c3c1d8882d864d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.3.1"
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
git-tree-sha1 = "cf7fd30387559f5bacd4abfb6781e01543402bce"
uuid = "2d09df54-9d0f-5258-8220-54c2a3d4fbee"
version = "4.7.4"

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

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsAPI", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "5cf6c4583533ee38639f73b880f35fc85f2941e0"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.7.3"

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
git-tree-sha1 = "d7531b8dbacf19be09e36df85619556b05ceb1e5"
uuid = "a41e6734-49ce-4065-8b83-aff084c01dfd"
version = "1.4.2"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.2.1+1"

[[deps.SymbolicIndexingInterface]]
deps = ["Accessors", "ArrayInterface", "MacroTools", "RuntimeGeneratedFunctions", "StaticArraysCore"]
git-tree-sha1 = "4b7f4c80449d8baae8857d55535033981862619c"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.3.15"

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
deps = ["Adapt", "DiffRules", "ForwardDiff", "Functors", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NNlib", "NaNMath", "Optimisers", "Printf", "Random", "Requires", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "685387ff526b7f4bafc5fe093949315d2680ce25"
uuid = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"
version = "0.2.33"
weakdeps = ["PDMats"]

    [deps.Tracker.extensions]
    TrackerPDMatsExt = "PDMats"

[[deps.TranscodingStreams]]
git-tree-sha1 = "71509f04d045ec714c4748c785a59045c3736349"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.10.7"
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

[[deps.Turing]]
deps = ["ADTypes", "AbstractMCMC", "AdvancedHMC", "AdvancedMH", "AdvancedPS", "AdvancedVI", "BangBang", "Bijectors", "DataStructures", "Distributions", "DistributionsAD", "DocStringExtensions", "DynamicPPL", "EllipticalSliceSampling", "ForwardDiff", "Libtask", "LinearAlgebra", "LogDensityProblems", "LogDensityProblemsAD", "MCMCChains", "NamedArrays", "Printf", "Random", "Reexport", "Requires", "SciMLBase", "Setfield", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "0e61d150c55162770c9dd904aa24a271921689e7"
uuid = "fce5fe82-541a-59a6-adf8-730c64b5f9a0"
version = "0.30.7"

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
git-tree-sha1 = "7209df901e6ed7489fe9b7aa3e46fb788e15db85"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.65"

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
deps = ["Libdl", "Pkg"]
git-tree-sha1 = "e5becd4411063bdcac16be8b66fc2f9f6f1e8fe5"
uuid = "f67eecfb-183a-506d-b269-f58e52b52d7c"
version = "1.0.10+1"

[[deps.Xorg_libSM_jll]]
deps = ["Libdl", "Pkg", "Xorg_libICE_jll"]
git-tree-sha1 = "4a9d9e4c180e1e8119b5ffc224a7b59d3a7f7e18"
uuid = "c834827a-8449-5923-a945-d239c165b7dd"
version = "1.2.3+0"

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
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

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
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

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
# ╟─ac0b951d-5260-40f5-86ba-1664f264ae21
# ╠═e869df0a-4005-46f8-a108-dd86e0ab2aac
# ╠═733dae80-07da-4ac9-9b58-517c0c2f6250
# ╠═d9015225-b635-42ad-ae96-fe7772a031b7
# ╠═b5f71893-a54a-4b2d-824c-27593a8dd781
# ╠═727e041b-fe08-4f7d-ad19-e3c57772c967
# ╟─283243e9-25a5-49b7-af83-defb59b47a74
# ╠═1fc989c1-99c9-4e26-9ed1-ef426ced9897
# ╟─a9a95df8-797c-4d43-b043-4e6b10fc4246
# ╠═078fdb65-5bd6-4b0d-b672-617f5912480d
# ╟─7fb1e6fa-1881-44a3-a409-cdb632b8e4e9
# ╠═f00222ef-b0d3-4464-87ef-6da1adbb54ac
# ╟─c199328f-81af-4e7c-8fa9-fac5fbeedc8a
# ╠═72bdf4a7-9563-4495-9f0c-72b43a76e8a8
# ╟─646fc015-eb4f-46e0-b483-1af49c9660bb
# ╠═f8682d46-7ee7-4fd2-a64f-c783360572e1
# ╠═4ace5da6-a36e-4d92-856d-2409238ccaa1
# ╠═41e60936-8367-4b04-9bb8-df9fb517a51f
# ╟─195af951-1ed0-420c-a939-e7883f8fd618
# ╠═93e9248c-2c0b-474c-aa9f-e9c66dcb6a00
# ╠═4c26c5a1-55e2-4007-9085-96ee776e7ebe
# ╠═ee759da7-cc6d-4fd2-8630-e29b323027c4
# ╟─5141dfdf-490d-479e-ac58-63c929ae8fd1
# ╟─611c3828-f01f-4721-830b-736b28620e7e
# ╠═ad511be2-fd88-4aba-a830-21e242d994f1
# ╟─5a2f79ca-2d3e-4cd4-9de9-7c7e283a5052
# ╠═94b5539b-4374-40b8-9501-8d3df49f20c3
# ╠═c47284e8-7686-49c8-8d10-2a8460f673cd
# ╠═ed2f98b3-34bf-4ce5-9ef7-ef3a5499e8ff
# ╠═6c96a6c6-df1d-4dda-8d1d-49b7d13314c4
# ╠═7994aea2-7b06-47cc-86f2-6afcda5a1707
# ╠═0479f514-1b96-4115-beaa-35a96c40a1d7
# ╠═9a1a6b7f-8810-4a14-910a-2ff422de4289
# ╠═788ea3c8-d94d-4201-b860-3f085f18f9e2
# ╠═3914cc70-e0c2-4b91-a456-5a301597e0fe
# ╠═1efdafc3-497f-434e-9a16-97636a4cfc4b
# ╠═5868fb4a-eb92-46c4-a753-6e9459b0a006
# ╠═358b7b46-129a-464d-86f0-2a1a8da10f3d
# ╠═8ddad81f-78fd-4a48-953c-d3480d6a3466
# ╠═e64277de-23c5-4ec9-ba57-ce39a39add2a
# ╠═485d49f2-e36b-4a22-aecb-84a51b8075e5
# ╟─45122674-c5d2-4f61-af03-c74482618e90
# ╠═3b7ca48f-078f-4eef-9d0c-fa8724e711d3
# ╠═40c173f3-3dbb-4907-9188-632d34b3d7cf
# ╟─39dc811c-2742-4977-a203-c9fdcb5b218d
# ╠═85bb82da-efe7-4b34-8af5-cf60ae6e4757
# ╟─53806285-ea68-4f5c-b3fb-a382a894ec56
# ╠═59b9a24b-6967-418b-a4f8-e67ceb0a5474
# ╠═74b85675-515a-4168-9739-8e8eeb42dab1
# ╠═f4d22dcc-81e8-4279-9eb3-861f0eeb5f83
# ╟─ed541621-2245-49f9-9672-31e20b9b7765
# ╟─47d9566c-93ec-4f70-b7b6-5586193bcdef
# ╠═1e5a39c0-6b5b-4d29-826e-e68c31c8f34e
# ╟─e8f6166f-20e5-40a2-a8fc-692ea8704b6d
# ╠═f74d5bc3-747b-4b12-9fb2-7e4a19cfe2c1
# ╠═fa9522ce-d91d-4cbd-9a1a-fe63fd2b7d15
# ╟─41fc983a-9209-4ff5-b9fa-5798c7d387af
# ╟─0f8d2476-7379-4bec-8a6f-e6ef81066ebb
# ╠═4632e385-2417-4683-9e31-72825cf5501c
# ╠═bf763ccd-2c72-4529-b6ac-747f39f1b9cf
# ╠═9aa0386d-6b6d-4892-b412-a8e28c0823d8
# ╠═ef2e821a-d947-40e1-9855-79819aec5dbb
# ╠═e1e48fb9-bb0f-4fe6-a34e-46ea2ced2510
# ╟─e259cf96-eb70-4fe7-9c25-1f25686b1faa
# ╠═bff2a56e-e799-4d50-b97b-79983df86565
# ╠═5c26fd02-6695-4f3d-8f17-37c9b2ada2e6
# ╟─941248e9-c1ec-4d6a-8a2a-dbdd9aee17d8
# ╠═97a58b2a-a200-4249-acf3-c52d28ca6aea
# ╠═7174161a-6536-4ec7-a89e-2c385de7052c
# ╠═f4955154-ea66-4523-aacd-1a4beef6d41b
# ╠═caa5e742-7606-43fa-8ae3-a1287ff24951
# ╠═2f524064-abcc-40a1-a21e-99a0a4636545
# ╟─0f92b3fa-1b99-45f4-8a8e-5b7ea33a464d
# ╠═cb2d9bdf-3cf3-48f2-a984-5440dba08ad9
# ╠═29f7fc44-1d5c-4912-a0b0-07a7e97cfe26
# ╟─bb21db38-31cf-4e88-86d2-922d62533769
# ╠═4f7bfda2-297d-432d-83c9-c931f5f62868
# ╠═90d5c3e8-a045-4d96-aebc-2ec99609e10b
# ╠═3babf620-dd01-45ae-b21c-e46e136057f6
# ╠═9a5d927d-e816-4f5f-a460-c89a507ce1ae
# ╠═b3778ab5-03b7-4ba5-9501-3e6bb643e4d5
# ╟─b55cffd3-d5ce-41db-968d-0b54b1b872a7
# ╠═e8765238-eec6-41c0-9c8c-148c9e51aad9
# ╠═fd1f8ae2-6839-4f7e-9141-66824490df72
# ╠═3a3537ec-039a-434d-a7d4-15ab41eb97d8
# ╠═fd90af56-427c-47a6-aa01-ef7ee6399a40
# ╠═421a7308-637f-4e55-969d-3afa26cbfc6c
# ╠═0caec6f7-af0d-4d89-b682-763c1e14af93
# ╠═63ca60f4-f5c6-4928-86bb-f6d131654bc4
# ╠═adb89664-66d8-4dbb-8f42-6043dcc09109
# ╟─fda881bd-9075-41be-b59d-b930f5444095
# ╠═9904cc2f-02f1-44d7-9831-fcefe95fe71d
# ╟─662b087b-b302-4ecb-95a9-cd696a74fcbc
# ╠═a09a81fb-580d-45d5-9893-121a22a3555f
# ╟─d3389c26-f9dd-4349-8d0b-4f3f9bb93b91
# ╠═f17ea741-c98f-4c88-94d2-03a3ca0d08fe
# ╠═640bc9cb-0967-4a18-8e1d-5a3ed4a9b33c
# ╟─9ae21be4-07ce-4ac9-ab58-4637ffd2281e
# ╠═78449377-ffcd-41da-8466-d2059c3d406a
# ╠═c10300fb-72a0-4668-8bb4-fa4be69b03c7
# ╠═1e502519-f1ed-4c83-ba8d-d96e66269d4e
# ╟─124a5a18-3a96-4394-9836-aa13266a936e
# ╠═823b783e-f114-427e-b4b4-f135eec09d86
# ╟─3d481718-a252-4f1c-9db9-289bd659982b
# ╠═c62dcfeb-fdb8-4d5d-a51d-286caddf4e00
# ╠═ab263a84-4612-4459-bf50-78bf0f236e44
# ╟─8b225437-50c2-40f8-aa10-0e0c1b64fa5b
# ╟─410933c5-0353-4060-9879-d08a84bb66df
# ╟─45d6b219-852b-4941-a09e-2128dfc88939
# ╠═f6516e63-a3f0-4bcb-a8ee-579ca95a95c3
# ╠═77c257c8-d4f4-4f33-9038-7f33123c5951
# ╠═fe4d08db-f84f-44ae-8499-5ef349e5806f
# ╠═fdad6aeb-79c0-4db5-8ac0-15b14444a679
# ╠═9f8aaf9c-8f23-4d90-b235-5d953713546e
# ╠═c41a1a22-36e7-46c8-88a7-04c8283fe681
# ╠═bc123b91-16a7-47c1-b4ed-241412065d27
# ╟─aa3e88f8-5802-48f8-b4dc-a0655ad38ffb
# ╠═41138aaa-52fb-467c-89a4-37edc46f170e
# ╟─aed57454-46c0-4abe-b0f7-8b03b8a78d48
# ╠═b8543e08-fb9d-442d-b3c3-93710660bb54
# ╟─7a2a581a-65a4-4d1f-96a0-03621d8694f0
# ╠═0bcd703f-3f33-471e-9a9f-e0fafcbb14ea
# ╟─ded8c2cc-498f-4717-89f1-73b1ad8bef16
# ╠═07e15ebd-d4c3-4960-9af7-59eff42cdd05
# ╟─e48c366c-ed2b-4005-9d0b-aa77d7bae51d
# ╠═31774687-7bbb-4474-affe-7aa0e6d6635f
# ╟─55069810-e31b-43bf-9af4-cb4d4594f788
# ╠═1bf4d82f-f083-45b1-89b8-b14b3cfde07a
# ╟─f49b25b8-06d0-4f11-948d-b12e74ea665d
# ╠═73baf70d-c5b3-4104-9075-f1376858143b
# ╟─cec77f99-48ea-4a81-9a72-bcff3574bf12
# ╠═bcb4b829-939c-48ac-96a3-7b6d53367c7f
# ╟─47f11b04-e951-4c42-822b-18baa6b34766
# ╠═3853f959-3ffe-4f4f-bb9f-5501845f40c9
# ╟─2f218914-d9e0-45cd-b9fd-89e35bfcdcc9
# ╠═76b82e84-62bc-43e4-8d39-f96ce0e82ca1
# ╟─5197af99-c495-4193-8b10-58df5a1756a2
# ╠═5f6fd968-7dc7-40f8-918c-7d07a0dbed97
# ╟─d4f685d5-10da-4597-b987-267d47e23c90
# ╠═0f333241-27fd-44d5-9499-2329414b5340
# ╟─b1b3d896-b1a6-4684-b0d2-3116d7ba76f0
# ╟─15a2f5fe-da00-4524-9462-a9b91e9b71d2
# ╠═2c51f054-46d1-41c6-8d9d-05e4f9b2fc0d
# ╠═c09d043f-566b-43c5-bf90-82e14d682a7b
# ╠═8b3ec669-e0f1-4fbf-a8b9-066fc4faa5d3
# ╠═02b0e6c8-12ba-46ee-a703-7b7f507560d6
# ╠═d33289fb-ff49-41c5-bf68-0472e92a6800
# ╟─896b01ce-9e16-42e3-876e-568011faf107
# ╠═29d5a336-ea7e-4ae7-b001-0d2fef59c85b
# ╟─b38c9b77-11ea-457e-9e94-aea8601c339f
# ╠═4b7c2f1f-1bdf-4442-8033-03544a00dd4e
# ╠═67ef36b0-7244-42ee-a7ad-bbecad0cb567
# ╠═2dacd63f-b12a-461f-8509-ac557744d612
# ╠═c6535255-66dd-4d99-bd31-19e67f8ba055
# ╠═69e5abc8-4e53-4842-8cf2-5fc0bf6b900c
# ╠═e2c9ad5f-3130-4927-9d78-c5f416ebcceb
# ╠═d6392293-db93-4be9-8fe5-383e5c1a4188
# ╟─95038f89-670d-4eb0-9f17-c7aca823ae40
# ╠═64ebf7d0-9715-4a9e-a230-994c6a5c860e
# ╠═dabc23d9-0789-46b7-b4c7-6a57cfc9ede5
# ╠═cbfd99c7-9f83-4d61-93de-0c1c8e751bba
# ╠═640874cb-242b-46b0-856a-3377e6e58c9b
# ╠═844417a4-b952-415f-872a-197932a8092b
# ╠═b42814ca-247d-456b-9017-4b84fa146626
# ╠═efadbcdd-edfe-4535-b683-336a8aab1864
# ╠═6c0440d4-3073-4d1d-9973-b6c3da09758c
# ╠═e9b7616d-a5cb-4eea-9afe-e18d29d858f5
# ╠═80f475ca-4ed8-4923-865f-f074cbe6117e
# ╟─59b23c71-f172-4aa5-ad3e-2f1b0876188f
# ╠═2106ac11-33de-4673-bc1f-32ecb57089f6
# ╠═048318ba-f836-4cdf-9e73-7a785c736297
# ╠═f73d822c-a815-4a35-b0cf-c11c0c30c6ce
# ╠═32ecb432-7176-4aa3-9369-b5de15634bdc
# ╠═7ec1588b-54fb-4803-9e21-2dd9e79ba7c9
# ╠═69510bfa-79c0-4bca-87dc-4ec7b8ed94af
# ╠═5792f4ff-f1bd-48bb-968a-0ebc1a3b4c53
# ╠═39dbf2e7-13fa-4c21-800e-80d7af55d03e
# ╠═76c05007-037d-48d9-86b7-9f37a799e546
# ╠═63eb903d-c425-46a0-8433-c80af6470bb1
# ╠═ff0a1377-9d07-4d88-a06c-38a91a6b12d1
# ╠═a931dd64-2491-4a11-af2e-0901041bb0be
# ╠═b1581df7-c821-483d-a6a9-e446e3245572
# ╠═cd4ce03c-84f1-4678-b74d-3e98ed510300
# ╟─4f211432-0c05-4a47-a9ae-01d67a3f6c4a
# ╠═200694d2-400b-4510-b232-a3e3e8238ae5
# ╠═8096b9a1-faaf-4bfb-a898-16324ddca400
# ╠═94b4e89f-cc44-4cbe-b3ea-bfdf2414858e
# ╠═523ec911-c963-436d-a96f-552c08b5b95a
# ╠═b1c7da74-31f2-47fd-bce1-099dc64545bb
# ╠═9dd72017-8504-46f8-b5d0-789bd1ed1d2a
# ╠═ea489813-0478-4e72-98cb-b6ab92f41a4e
# ╠═7775c476-4b7e-4373-800d-40dd160177f8
# ╠═98f9395b-f436-476b-be03-a9898447894f
# ╠═99a9860b-34ef-43c4-a817-8ef90f5ffbf6
# ╠═7d1bd042-96a3-4eb9-9942-599c35d3d92b
# ╠═7c8d4ad0-215d-4d9f-9034-c7a0c8f6734c
# ╠═d4640e8c-b1cc-4d06-adc8-96193f7b2790
# ╠═1f440c0e-a202-4a28-95d1-3c71337a2ba7
# ╠═682fdb58-c13e-48b0-8529-a4cd53bdebb2
# ╠═030db799-b6e1-458d-814e-be806dd296dc
# ╠═edacad84-bc81-4dc0-94e5-5cd2809bdae2
# ╠═a8caa1df-141f-4665-a864-9ae960682c80
# ╠═de16bb86-0468-4db3-a085-cf11d437db17
# ╠═fc186a6d-7afa-43f1-9545-c14399a6d708
# ╠═3c752715-c8e0-473d-b70a-7769fee640e1
# ╠═20a3bb3c-04b5-42dd-8013-3f689d782d00
# ╠═9d52314c-e559-48d6-ad0f-76a4c6f36b67
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
