using TOML

let
    root = dirname(@__DIR__)
    project = TOML.parsefile(joinpath(root, "Project.toml"))
    target = get(ENV, "GROUP", "Enzyme") == "CUDA" ? "enzyme_cuda" : "enzyme"
    names = project["targets"][target]
    packages = merge(project["deps"], project["weakdeps"], project["extras"])
    deps = Dict(name => packages[name] for name in names)
    compat = Dict(name => project["compat"][name] for name in [names; "julia"])
    mktempdir() do envdir
        open(joinpath(envdir, "Project.toml"), "w") do io
            TOML.print(io, Dict("deps" => deps, "compat" => compat))
        end
        code = """
        using Pkg
        Pkg.develop(path = $(repr(root)))
        Pkg.instantiate()
        include($(repr(joinpath(@__DIR__, "qa", "enzyme.jl"))))
        if $(target == "enzyme_cuda")
            include($(repr(joinpath(@__DIR__, "gpu_kernel_de", "enzyme_cuda_records.jl"))))
        end
        include($(repr(joinpath(@__DIR__, "gpu_kernel_de", "enzyme_transfers.jl"))))
        include($(repr(joinpath(@__DIR__, "gpu_kernel_de", "enzyme.jl"))))
        """
        run(`$(Base.julia_cmd()) --project=$envdir -e $code`)
    end
end
