using JSON3
using DataStructures

include("syntax.jl")

Base.@kwdef struct Grammar
    scopeName = nothing
    patterns = nothing
    repository = nothing
end

Base.@kwdef struct Pattern
    name = nothing
    match = nothing
    _begin = nothing
    _end = nothing
    captures = nothing
    begin_captures = nothing
    end_captures = nothing
    include = nothing
    patterns = nothing
end

Base.@kwdef struct Capture
    id = nothing
    name = nothing
end

const grammar_file = joinpath(@__DIR__, "julia-grammar.json")

generate(x) = x
generate(x::Vector) = generate.(x)
generate(x::Vector{Capture}) = OrderedDict(map(x -> string(x.id) => OrderedDict("name" => x.name), x)...)
generate(g::Grammar) = OrderedDict(filter(!isnothing, generate.(Ref(g), [:scopeName, :patterns, :repository]))...)

generate(g::Grammar, key::Symbol) = begin
    val = getproperty(g, key)
    isnothing(val) ? nothing : string(key) => generate(val)
end

generate(pat::Pattern) = begin
    fields = [replace(string(key), r"^_" => "") => getproperty(pat, key) for key ∈ fieldnames(typeof(pat))]
    OrderedDict(map(x -> x.first => generate(x.second), filter(x -> !isnothing(x.second), fields))...)
end

generate(r::Regex) = r.pattern

function generate(filename::String, g::Grammar)
    filename = last(splitext(filename)) == ".json" ? filename : filename * ".json"
    open(filename, "w+") do io
        write(io, JSON3.write(generate(g)))
    end
end

regex_reserved_chars = ['=', '+', '-', '!', '|', '(', ')', '[', ']', '{', '}', '\\', '^', '$', '*', '?', '.', ':', '/']

function escape(regex_char)
    regex_char ∉ regex_reserved_chars && return regex_char
    "\\$regex_char"
end



escape(str::String) = string(map(x -> escape(Char(x)), collect(str))...)

regex_or(exs) = string("(?:", join(escape.(string.(exs)), '|'), ")")

g = Grammar(scopeName="source.julia", repository=[], patterns=[
    Pattern(name="comment.line.number-sign", _begin=r"#(?!=)", _end=raw"$"),
    Pattern(name="comment.block", _begin="#=", _end="=#"),
    Pattern(name="keyword.other.begin", match="begin"),
    Pattern(name="keyword.other.end", match="end"),
    Pattern(name="keyword.control", match=r"(if|elseif|else|continue|return|try|catch|finally|for|while)"),
    Pattern(name="keyword.other.const", match=r"\bconst\b"),
    Pattern(name="string.regexp", _begin="r\"", _end="\""),
    Pattern(name="string.quoted.triple", _begin="\"\"\"", _end="\"\"\""),
    Pattern(name="string.quoted.double.regular", _begin="\"", _end="\"", patterns=[
        Pattern(name="string.interpolated", match=r"(?:\$\w+|\$\(.*?\))"),
    ]),
    Pattern(name="string.quoted.single", _begin="'", _end="'"),
    Pattern(name="keyword.other.function", match="function"),
    Pattern(match=r"(\S+)(?=\()", captures=[
        Capture(id=1, name="entity.name.function"),
    ]),
    Pattern(match=r"(macro) (.*)\s*(?=\()", captures=[
        Capture(1, "keyword.other.macro"),
        Capture(2, "entity.name.macro"),
    ]),
    Pattern(name="call.macro", match=r"@\w*"),
    Pattern(name="operator.unary", match=Regex(regex_or(unary_operators))),
    Pattern(name="operator.binary", match=r"\s(?:in|isa)\s"),
    Pattern(name="operator.binary", match=Regex(regex_or(setdiff(binary_operators, [:in, :isa, :.])))),
    Pattern(name="constant.numeric", match=r"(?<![\w\.])(?:\d+\.*\d*|\d*\.*\d+)(?:[fe][\+-]?\d+)?"),
    Pattern(name="constant.language", match="(true|false|nothing)"),
    Pattern(name="punctuation.paren.left", match=r"\("),
    Pattern(name="punctuation.paren.right", match=r"\)"),
])

generate(grammar_file, g)
