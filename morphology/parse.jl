using CitableParserBuilder
using CitableText
using CitableCorpus
using Orthography
using PolytonicGreek
using Kanones, Kanones.FstBuilder
using EditorsRepo

projectshort = "va-revisions"

# Assume that these two directories are checked out next door.  
# Adjust if necessary.
function kroot()
    joinpath((pwd() |> dirname |> dirname), "Kanones.jl")
end
function hmt_lexicon()
    joinpath((pwd() |> dirname |> dirname), "hmt-lexicon", "kdata")
end


function editorsrepo() 
    repository(dirname(pwd()))
end

function customparser(; krootdir = kroot(), hmtlexdata = hmt_lexicon())
    fstsrc  =  joinpath(krootdir, "fst")
    coreinfl = joinpath(krootdir, "datasets", "core-infl")
    corevocab = joinpath(krootdir, "datasets", "core-vocab")
    lysias = joinpath(krootdir, "datasets", "lysias")
    scholia = joinpath(hmtlexdata, "scholia")

    datasets = [corevocab, coreinfl, lysias, scholia]
    kd = Kanones.Dataset(datasets)
    tgt = joinpath(krootdir,  "parsers", "scholiaparser")
    buildparser(kd,fstsrc, tgt; force = true)
end

# 1. load a corpus by constructing normalized version of every text 
# cataloged in repository
function loadcorpus(repo = editorsrepo())
    psgs = []
    for u in citation_df(repo)[:,:urn]
        push!(psgs, EditorsRepo.normalized_passages(repo, u))
    end
    psgs |> Iterators.flatten |> collect |> CitableTextCorpus
end
    

# 2. tokenize 
ortho = literaryGreek()
tknized = tokenizedcorpus(c,ortho)

# 3. parse and write to disk
function reparse(tkncorpus, parser, projname)
    parsed = parsecorpus(tkncorpus, parser)
    open(joinpath(pwd(), "$(projname)-parses.cex"),"w") do io
        write(io, delimited(parsed))
    end
end

# Execute this repeatedly as you edit/revise:
function rebuild()
    p = customparser(kroot(), hmt_lexicon())
    reparse(tknized, p, projectshort)
end





# For labelling lemmata:
lsj = Kanones.lsjdict(joinpath(kroot(), "lsj", "lsj-lemmata.cex"))