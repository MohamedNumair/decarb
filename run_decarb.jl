"""
Batch driver for DECARB cases.

Usage:
    julia --project=. run_decarb.jl [--solver highs|gurobi] [case-list.txt]

The default solver is HiGHS. The case list defaults to `bdg_path.txt`.
"""

using DECARB

function usage(io::IO=stdout)
    println(io, """
    Usage:
        julia --project=. run_decarb.jl [--solver highs|gurobi] [case-list.txt]

    Options:
        --solver NAME   Solver to use: highs (default) or gurobi.
        -h, --help      Show this help message.
    """)
end

function parse_args(args::Vector{String})
    solver = "highs"
    list_file = nothing
    i = 1

    while i <= length(args)
        arg = args[i]

        if arg in ("-h", "--help")
            usage()
            return nothing
        elseif arg == "--solver"
            i == length(args) && error("--solver requires a solver name")
            solver = lowercase(args[i + 1])
            i += 2
        elseif startswith(arg, "--solver=")
            solver = lowercase(split(arg, "="; limit=2)[2])
            i += 1
        elseif startswith(arg, "-")
            error("unknown option: $arg")
        elseif isnothing(list_file)
            list_file = arg
            i += 1
        else
            error("expected at most one case-list path")
        end
    end

    solver in ("highs", "gurobi") ||
        error("unsupported solver '$solver'; use highs or gurobi")

    return (
        solver,
        isnothing(list_file) ? joinpath(@__DIR__, "bdg_path.txt") : abspath(list_file),
    )
end

function optimizer_for(solver::String)
    solver == "highs" && return nothing  # DECARB's default optimizer

    Base.find_package("Gurobi") === nothing &&
        error("Gurobi is not available in the active Julia environment. " *
              "Install it there, then rerun with --solver gurobi.")

    @eval import Gurobi
    return Gurobi.Optimizer
end

function run_batch(args::Vector{String}=ARGS; optimizer=nothing)
    parsed = parse_args(args)
    isnothing(parsed) && return nothing

    solver, list_file = parsed
    isfile(list_file) || error("case list not found: $list_file")

    selected_optimizer = isnothing(optimizer) ? optimizer_for(solver) : optimizer

    lines = strip.(readlines(list_file))
    case_paths = filter(line -> !isempty(line) && !startswith(line, "#"), lines)

    for raw_path in case_paths
        path = strip(raw_path, ['"', '\''])
        case = basename(normpath(path)) == "in" ? dirname(normpath(path)) : normpath(path)

        if isnothing(selected_optimizer)
            DECARB.run_decarb!(case)
        else
            DECARB.run_decarb!(case; optimizer=selected_optimizer)
        end
    end

    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_batch()
end