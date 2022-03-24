#= 
=#
using Pkg
Pkg.activate(joinpath(pwd(), "dashboard"))
Pkg.resolve()
Pkg.instantiate()

DASHBOARD_VERSION = "0.17.0"

using Dash
using CitableBase
using CitableText
using CitableCorpus
using CitableObject
using CitableImage
using CitablePhysicalText
using CitableTeiReaders
using EditionBuilders
#using Orthography
using EditorsRepo

THUMBHEIGHT = 200
TEXTHEIGHT = 600

r = repository(pwd())

assetfolder = joinpath(pwd(), "dashboard", "assets")
app = dash(assets_folder = assetfolder, include_assets_files=true)

app.layout = html_div(className = "w3-container") do
    html_div(className = "w3-container w3-light-gray w3-cell w3-mobile w3-border-left  w3-border-right w3-border-gray", children = [dcc_markdown("*Dashboard version*: **$(DASHBOARD_VERSION)** ([version notes](https://homermultitext.github.io/dashboards/alpha-search/))")]),
    
    html_h1("HMT project: DSE verification dashboard"),

    html_div(className="w3-panel w3-round w3-border-left w3-border-gray w3-margin-left w3-margin-right",
        dcc_markdown("*Load or update data, then choose a surface to validate. Optionally, filter set of texts to verify*.")
    ),
   
    html_div(className = "w3-container",
        children = [
        html_div(className = "w3-col l4 m4 s12",
        children = [
            html_div(children = dcc_markdown("*No data loaded*"), id="datastate"),
            html_button("Load/update data", id="load_button")
        ]),


        html_div(className = "w3-col l4 m4 s12",
        children = [
            dcc_markdown("*Choose a surface*:")
            dcc_dropdown(id = "surfacepicker")
        ]),
      


        html_div(className = "w3-col l4 m4 s12",
        children = [
            dcc_markdown("*Texts to verify*:")
            dcc_dropdown(
                id = "texts",
                options = [
                    (label = "All texts", value = "all"),
                    (label = "Iliad", value = "iliad"),
                    (label = "scholia", value = "scholia")
                ],
                value = "all",
                clearable=false
            )
        ]),
       
        ]
    ),

    html_div(id="dsecompleteness", className="w3-container"),
    html_div(id="dseaccuracy", className="w3-container")#,

end

"Update surfaces menu and set user message about number of times data loaded."
function updaterepodata(n_clicks)
    msg = if isnothing(n_clicks)
        dcc_markdown("*No data loaded yet*")
    elseif n_clicks ==  1
        dcc_markdown("*Data loaded*.")
    else
        dcc_markdown("""*Data loaded **$(n_clicks)** times*.""")
    end


    menupairs = [(label="", value="")]
    for s in surfaces(r, strict = false)
		push!(menupairs, (label=string(s), value=string(s)))
	end
    (msg, menupairs )
 
end


function hmtdse(edrep, surf, ht, textfilter)
    iiif = EditorsRepo.DEFAULT_IIIF
    ict = EditorsRepo.DEFAULT_ICT

    triples = dsetriples(edrep, strict = false)
    surfacetriples = filter(row -> urncontains(surf, row.surface), triples)
    textsurfacetriples = surfacetriples
    if textfilter == "iliad"
        textsurfacetriples = filter(row -> urncontains(CtsUrn("urn:cts:greekLit:tlg0012.tlg001:"), row.passage), surfacetriples)
    elseif textfilter == "scholia"
        textsurfacetriples = filter(row -> urncontains(CtsUrn("urn:cts:greekLit:tlg5026:"), row.passage), surfacetriples)
    end
    images = map(tr -> tr.image, textsurfacetriples)
    ictlink = ict * "urn=" * join(images, "&urn=")
    imgmd = markdownImage(dropsubref(images[1]), iiif; ht = ht)
    verificationlink = string("[", imgmd, "](", ictlink, ")")

    
    hdr = "## Completeness of indexing:\n\nPage: *$(objectcomponent(surf))*. Texts included: *$(textfilter)*\n\nThe image is linked to the HMT Image Citation Tool where you can verify the completeness of DSE indexing.\n\n"

    hdr * verificationlink
    

end

function hmtdseaccuracy()
    "Hi. Filter texts for accurcy, too, just like completeness."
end

# Update surfaces menu and user message when "Load/update data" button
# is clicked:
callback!(
    updaterepodata,
    app,
    Output("datastate", "children"),
    Output("surfacepicker", "options"),
    Input("load_button", "n_clicks"),
    prevent_initial_call=true
)


# Update validation/verification sections of page when surface is selected:
callback!(
    app,
    Output("dsecompleteness", "children"),
    Output("dseaccuracy", "children"),
    Input("surfacepicker", "value"),
    Input("texts", "value")
) do newsurface, txt_choice
    if isnothing(newsurface) || isempty(newsurface)
        (dcc_markdown(""), dcc_markdown(""))#, dcc_markdown(""))
    else
        surfurn = Cite2Urn(newsurface)
        completeness = dcc_markdown(hmtdse(r, surfurn, THUMBHEIGHT, txt_choice))
       
       
   

        accuracyhdr = "### Verify accuracy of indexing\n*Check that the diplomatic reading and the indexed image correspond.*\n\n"
        #accuracypassages = indexingaccuracy_html(r, surfurn, height=TEXTHEIGHT, strict = false)
        #accuracy = dcc_markdown(accuracyhdr * accuracypassages)
        accuracy = hmtdseaccuracy()
      
        (completeness, accuracy)
    end
end

run_server(app, "0.0.0.0", 8051, debug=true)