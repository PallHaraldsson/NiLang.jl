using DelimitedFiles
using UnicodePlots

function analyze_flow(xs0, logp0, xs, logp; xlim=[-5,5], ylim=[0,1])
    order = sortperm(xs0)[1:10:end]
    lineplot(xs0[order], exp.(logp0[order]); xlim=xlim, ylim=ylim,title="p(x), before transformation") |> println

    fy = fit(Histogram, xs, range(xlim..., length=200), closed=:left)
    xticks = (fy.edges[1][1:end-1] .+ fy.edges[1][2:end]) ./ 2
    lineplot(xticks, fy.weights; xlim=xlim, title="data, after transformation") |> println

    order = sortperm(xs)[1:10:end]
    lineplot(xs[order], exp.(logp[order]); xlim=xlim, ylim=ylim,title="p(x), after transformation") |> println
end

function forward_sample(μ, σ, field, θ; nsample=100, Nt=100, dt=0.01, xlim=[-5,5], ylim=[0,1])
    # source distribution
    source_distri = Normal(μ, σ)
    xs0 = rand(source_distri, nsample)
    logp0 = max.(logpdf.(source_distri, xs0), -10000)

    # solving the ode, and obtain the probability change
    @newvar v_xs = copy(xs0)
    @newvar v_ks = copy(xs0)
    @newvar v_logp = copy(logp0)
    @newvar v_θ = θ
    @newvar field_out = 0.0
    tape = ode!(v_xs, v_ks, v_logp, field, field_out, v_θ, Nt, dt)

    play!(tape)
    analyze_flow(xs0, logp0, v_xs[], v_logp[]; xlim=xlim)
end

function get_loss_gradient!(forward, loss_out, θ)
    reset_grad!(forward)
    resetreg(forward)
    play!(forward)

    ll = loss_out[]

    grad(loss_out)[] = 1
    play!(forward')
    return ll, grad(θ)
end

function train(xs_target, θ; niter=100, Nt=100, dt=0.01, lr=0.1)
    μ = 0.0
    σ = 1.0
    @newvar loss_out = 0.0
    @newvar logp_out = zeros(Float64, length(xs_target))
    @newvar v_xst = xs_target
    @newvar v_kst = copy(xs_target)
    @newvar field_out = 0.0
    @newvar jacobian_out = zero(logp_out[])
    forward = ode_loss!(μ, σ, logp_out, v_xst, v_kst, field, ode!,
        inv_normal_logpdf!, jacobian_out, field_out, loss_out, θ, Nt, dt)

    init_grad!(forward)
    local ll
    for i=1:niter
        logp_out[] .= 0.0
        loss_out[] = 0.0
        ll, θδ = get_loss_gradient!(forward, loss_out, θ)
        println("Step $i, log-likelihood = $ll")
        θ[] += θδ[] * lr
        @show θ[]
    end
    return ll, forward
end

=#
