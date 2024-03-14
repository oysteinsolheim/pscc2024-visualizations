using Colors
using CSV
using Dash
using DashBootstrapComponents
using DataFrames
using PlotlyJS

suppress_callback_exceptions = true

ns = 1000
part = 1
perp = 50
randomize = true


const NUM_EXTRA_DATA = 5

MAX_NUM_NEIGHBORS = 5
NEIGHBOR_IND = :new_num_lines

_files = filter(s->split(s, ".")[end]=="csv" , readdir("data/", join=true))

_current_file = "data/df_pca_tsne_umap_model1_1000_50_50_0.5.csv"


function read_data(file)
    df = CSV.read(file, DataFrame)
    df[!, "new_num_neighbors"] = [ifelse(v<MAX_NUM_NEIGHBORS, v, MAX_NUM_NEIGHBORS) for v in df.num_neighbors]
    df[!, "new_num_lines"] = [ifelse(v<MAX_NUM_NEIGHBORS, v, MAX_NUM_NEIGHBORS) for v in df.num_lines]

    return df
end

df = read_data(_current_file)
NUM_BUSES = maximum(df.labels)
app = dash(suppress_callback_exceptions=true)

ns_value = 1
input_level = 1

n_colors_node = NUM_BUSES
n_colors_node_neighbors = MAX_NUM_NEIGHBORS
colormap_node = distinguishable_colors(n_colors_node, colorant"red");
colormap_node_neighbors = distinguishable_colors(n_colors_node_neighbors, colorant"red");
_cmp_node = Dict(i=> c for (i,c) in enumerate(colormap_node))
_cmp_node_neighbors = Dict(i=> c for (i,c) in enumerate(colormap_node_neighbors))

pca_only=true

function create_layout(df)
    return Layout(
        id="layout1",
        autosize=false,
        width=900,
        height=900,
        xaxis=attr(domain=[0,1], range=[-125, 125], showticklabels=false, showgrid=false, zeroline=false), 
        yaxis=attr(anchor="x",domain=[0.45, 1.0], range=[-125, 125], showticklabels=false, showgrid=false, zeroline=false),
        xaxis2=attr(domain=[0, 1.0], range=[0,ns], showticklabels=false, overlaying="x3"),
        yaxis2=attr(anchor="x2", domain=[0.0, 0.4], range=[0, maximum(df.avail_gen)*1.1]),
        xaxis3=attr(domain=[0, 1.0], overlaying="x2", showticklabels=false, range=[0,ns], ticks="outside"),
        yaxis3=attr(anchor="x3", overlaying="y2", side="right", range=[0, 1+ maximum(df.total_lines_on_outage)]), 


    )
end


function make_scatter_list(df, name, xaxis, yaxis, _cmp, visible=true)
    return [
        scatter(
            sub_df, 
            x=:t, 
            y=name,
            xaxis=xaxis, 
            yaxis=yaxis, 
            name=string(name)*" $(sub_df[1, :labels])", 
            line_color=_cmp[sub_df[1, :labels]],
            visible=visible,
            showlegend=false
        ) for sub_df in groupby(df, :labels)
    ]
end

function create_traces(df; num_based=false, tsne=true, pca=true)
    _group_col = num_based ? NEIGHBOR_IND : :labels
    _cmp = num_based ? _cmp_node_neighbors :  _cmp_node
    if pca
        x_string = "pca_x$(input_level)"
        y_string = "pca_y$(input_level)"
    else
        x_string = tsne ? "tsne_x$(input_level)" : "umap_x$(input_level)"
        y_string = tsne ? "tsne_y$(input_level)" : "umap_y$(input_level)"
    end
    t1 = [
        scattergl(
            sub_df, 
            x=Symbol(x_string), 
            y=Symbol(y_string),
            mode=:markers,
            marker=attr(
                opacity=vcat(0.1*ones(ns_value-1), 1.0, 0.0*ones(ns-ns_value)),
                size=vcat(4*ones(ns_value-1), 12.0, 4*ones(ns-ns_value)),
                line_width=vcat(zeros(ns_value-1), 1.0, zeros(ns-ns_value)),
                line_color=:black,
                color=_cmp[sub_df[1, _group_col]]
            ), 
            hoverinfo="all",
            hovertemplate=["Bus: $(sub_df[i,:labels]), NN: $(sub_df[i, NEIGHBOR_IND])" for i in 1:length(sub_df[!,:labels])],
            showlegend=true,
            xaxis="x level $(input_level)",
            yaxis="y level $(input_level)",
            name="Bus $(sub_df[1, _group_col])"

        ) for sub_df in groupby(df, _group_col)
    ]
    t = [t1...]
    return t
end

l = create_layout(df)
t = create_traces(df, pca=pca_only)
app.layout = html_div(style=Dict("width"=>"100%")) do 
    html_div(style=Dict("width"=>"45%", "display"=>"inline-block")) do
        "Num connections-based colouring",
        dcc_radioitems(
            id="radioitems-1",
            options = [
                Dict("label" => "yes", "value" => 1),
                Dict("label" => "no", "value" => 0),
            ],
            value = 0,
            labelStyle = Dict("display" => "inline-block")
        ),
        html_br(),
        "Graph or line based numbering",
        dcc_radioitems(
            id="radioitems-2",
            options = [
                Dict("label" => "graph", "value" => 1),
                Dict("label" => "line", "value" => 0),
            ],
            value = 0,
            labelStyle = Dict("display" => "inline-block")
        ),
        "Max num neighbors",
        dcc_radioitems(
            id="radioitems-3",
            options = [
                Dict("label" => "1", "value" => 1),    
                Dict("label" => "2", "value" => 2),    
                Dict("label" => "3", "value" => 3),
                Dict("label" => "4", "value" => 4),
                Dict("label" => "5", "value" => 5),
            ],
            value = 5,
            labelStyle = Dict("display" => "inline-block")
        ),
        html_br(),
        "PCA or t-SNE or UMAP",
        dcc_radioitems(
            id="radioitems-pca-tsne-umap",
            options = [
                Dict("label" => "PCA", "value" => 2),
                Dict("label" => "t-SNE", "value" => 1),
                Dict("label" => "UMAP", "value" => 0),
            ],
            value = 1,
            labelStyle = Dict("display" => "inline-block")
        ),
        html_br(),
        "Data file",
        dcc_dropdown(
            id="dropdown-1",
            options = vcat(
                [Dict("label" => _file, "value" => _file) for _file in  _files]
            ),
            value = "examples/data/df_2_1000_1_200_rand_last.csv",
            multi=false
        ),
        dcc_graph(id = "figure_1", figure=Plot(t, l),),
        html_div(style=Dict("width"=>"100%", "display"=>"inline-block")) do
            html_div(style=Dict("width"=>"10%", "display"=>"inline-block")) do
                dbc_button("time -1", id="button-1", n_clicks=0, value=-1),
                dbc_button("time -10", id="button-10", n_clicks=0, value=-10),
                dbc_button("time -50", id="button-50", n_clicks=0, value=-50)
            end,
            html_div(style=Dict("width"=>"10%", "display"=>"inline-block", "float"=>"right")) do
                dbc_button("time +1", id="button+1", n_clicks=0, value=1),
                dbc_button("time +10", id="button+10", n_clicks=0, value=10),
                dbc_button("time +50", id="button+50", n_clicks=0, value=50)
            end
        end,
        html_br(),
        "Time",
        dcc_slider(
            id = "slider_1",
            min = minimum(1),
            max = maximum(ns),
            # marks = nothing,
            marks = Dict([Symbol(v) => Symbol(v) for v in vcat(1, collect(50:50:ns)...)]),
            updatemode="drag",
            value = ns,
            step = 1.0,
            tooltip=Dict("always_visible"=>true,"placement"=>"bottom")
        ),        
        html_br(),
        "Max number of points for each bus",
        dcc_slider(
            id = "slider_2",
            min = minimum(1),
            max =ns,
            # marks = nothing,
            marks = Dict([Symbol(v) => Symbol(v) for v in vcat(1, collect(50:50:ns)...)]),
            updatemode="drag",
            value = ns,
            step = 1.0,
            tooltip=Dict("always_visible"=>true, "placement"=>"bottom")
        ),
        html_br(),
        "Opacity for previous buses",
        dcc_slider(
            id = "slider_3",
            min = 0,
            max =1.0,
            # marks = nothing,
            marks = Dict([Symbol(v) => Symbol(v) for v in 0:0.05:1]),
            updatemode="drag",
            value = 0.8,
            step = 0.01,
            tooltip=Dict("always_visible"=>true, "placement"=>"bottom")
        ),
        "Size markers",
        dcc_slider(
            id = "slider_4",
            min = 0,
            max = 20,
            # marks = nothing,
            marks = Dict([Symbol(v) => Symbol(v) for v in 0:1:20]),
            updatemode="drag",
            value = 3.0,
            step = 0.5,
            tooltip=Dict("always_visible"=>true, "placement"=>"bottom")
        ),
        "Last timestep factor size",
        dcc_slider(
            id = "slider_5",
            min = 1,
            max = 10,
            # marks = nothing,
            marks = Dict([Symbol(v) => Symbol(v) for v in 1:10]),
            updatemode="drag",
            value = 1,
            step = 1,
            tooltip=Dict("always_visible"=>true, "placement"=>"bottom")
        ),
        "Last timestep line_width",
        dcc_slider(
            id = "slider_6",
            min = 0,
            max = 5,
            # marks = nothing,
            marks = Dict([Symbol(v) => Symbol(v) for v in 0:5]),
            updatemode="drag",
            value = 0,
            step = 1,
            tooltip=Dict("always_visible"=>true, "placement"=>"bottom")
        )       
    end,
    html_div(style=Dict("width"=>"45%", "margin-left"=>"3%","float"=>"right", "display"=>"inline-block")) do
        "Bus details",
        dcc_dropdown(
            id="dropdown-2",
            options = [
                Dict("label" => "Bus load", "value" => 1),
                Dict("label" => "Bus gen", "value" => 2),
                Dict("label" => "Available bus gen", "value" => 3),
                Dict("label" => "Bus curt", "value" => 4),
            ],
            value = [4],
            multi=true
        ),
        html_br(),
        "Embedding levels",
        dcc_radioitems(
            id="radioitems-4",
            options = vcat(
                [
                    Dict("label" => "Node input", "value" => 1),
                    Dict("label" => "Node input encoding", "value" => 2)
                ],
                [
                    Dict("label" => "MPL $i", "value" => i+2) for i in 1:4
                ]
            ),
            value = 6,
            labelStyle = Dict("display" => "inline-block")
        ),
        html_br(),
        "Buses to show",
        dcc_dropdown(
            id="dropdown-3",
            options = vcat(
                [Dict("label" => "All", "value" => 0)],
                [
                    Dict("label" => "Bus $i", "value" => i) for i in 1:NUM_BUSES
                ]
            ),
            value = [1, 2, 4, 5, 6, 9, 10],
            multi=true
        )
    end
end

callback!(
    app,
    Output("slider_1", "value"),
    Input("button-1", "n_clicks"),
    Input("button+1", "n_clicks"),
    Input("button-10", "n_clicks"),
    Input("button+10", "n_clicks"),
    Input("button-50", "n_clicks"),
    Input("button+50", "n_clicks"),
    State("slider_1", "value")
) do n_minus, n_plus, n_minus_10, n_plus_10, n_minus_50, n_plus_50, v_slider
    ctx = callback_context()
    if length(ctx.triggered) > 0
        triggered = ctx.triggered[1]
        if triggered.prop_id == "button+1.n_clicks"
            return min(ns, v_slider + 1)
        elseif triggered.prop_id == "button-1.n_clicks"
            return max(1, v_slider -1)
        elseif triggered.prop_id == "button+10.n_clicks"
            return min(ns, v_slider + 10)
        elseif triggered.prop_id == "button-10.n_clicks"
            return max(1, v_slider -10)
        elseif triggered.prop_id == "button+50.n_clicks"
            return min(ns, v_slider + 50)
        elseif triggered.prop_id == "button-50.n_clicks"
            return max(1, v_slider -50)
        end
    end
    return v_slider
end

callback!(
    app,
    Output("figure_1", "figure"),
    Input("radioitems-1", "value"),
    Input("radioitems-2", "value"),
    Input("radioitems-3", "value"),
    Input("radioitems-4", "value"),
    Input("radioitems-pca-tsne-umap", "value"),
    Input("dropdown-1", "value"),
    Input("dropdown-2", "value"),
    Input("dropdown-3", "value"),
    Input("slider_1", "value"),
    Input("slider_2", "value"),
    Input("slider_3", "value"),
    Input("slider_4", "value"),
    Input("slider_5", "value"),
    Input("slider_6", "value"),
    State("figure_1", "figure")
) do _color_num, graph_or_el, max_num_neigh, _level, _tsne, _file, visibility, bus, ns_value, delay_value, op, sz, fac_sz, lw, fig
    ctx = callback_context()
    fig_copy = copy(fig)
    
    if length(ctx.triggered) > 0
        triggered = ctx.triggered[1]
        if triggered.prop_id == "dropdown-1.value"
            # @infiltrate
            global df = read_data(_file)
            global NUM_BUSES = maximum(df.labels)
            global n_colors_node = NUM_BUSES
            global n_colors_node_neighbors = MAX_NUM_NEIGHBORS
            global colormap_node = colormap_node;
            global colormap_node_neighbors = colormap_node_neighbors;
            global _cmp_node = Dict(i=> c for (i,c) in enumerate(colormap_node))
            global _cmp_node_neighbors = Dict(i=> c for (i,c) in enumerate(colormap_node_neighbors))
            # @infiltrate
            new_d = create_traces(df, num_based=_color_num == 1, tsne=_tsne==1, pca=_tsne==2)
            new_l = create_layout(df)
            for i in eachindex(new_d)
                fig_copy[:data][i][:x] = new_d[i].x
                fig_copy[:data][i][:y] = new_d[i].y
            end
            fig_copy[:layout][:yaxis3] = new_l.yaxis3
        end
    end
    global MAX_NUM_NEIGHBORS = max_num_neigh
    n_bus = _color_num == 0 ? NUM_BUSES : MAX_NUM_NEIGHBORS
    global NEIGHBOR_IND = graph_or_el == 1 ? :new_num_neighbors : :new_num_lines
    bus_group = _color_num == 0 ? :labels : NEIGHBOR_IND
    if 0 in bus
        bus = collect(1:n_bus)
    end
    df[!, "new_num_neighbors"] = [ifelse(v<MAX_NUM_NEIGHBORS, v, MAX_NUM_NEIGHBORS) for v in df.num_neighbors]
    df[!, "new_num_lines"] = [ifelse(v<MAX_NUM_NEIGHBORS, v, MAX_NUM_NEIGHBORS) for v in df.num_lines]
    if _tsne==2
        x_string = "pca_x$(_level)"
        y_string = "pca_y$(_level)"
    else
        x_string = _tsne == 1 ? "tsne_x$(_level)" : "umap_x$(_level)"
        y_string = _tsne == 1 ? "tsne_y$(_level)" : "umap_y$(_level)"
    end
    for (i, sub_df) in enumerate(groupby(df, bus_group))
        fig_copy[:data][i][:x] = sub_df[!,x_string]
        fig_copy[:data][i][:y] = sub_df[!,y_string]
        fig_copy[:data][i][:name] = "Bus " * string(sub_df[1, bus_group])

        if _color_num == 0
            fig_copy[:data][i][:marker][:color] = "#"*hex(_cmp_node[sub_df[1, :labels]])
        else
            fig_copy[:data][i][:marker][:color] = "#"*hex(_cmp_node_neighbors[sub_df[1, NEIGHBOR_IND]])
        end
        
        if _color_num == 0
            fig_copy[:data][i][:marker][:size] = vcat(
                sz*ones(ns_value-1), 
                sz*fac_sz, 
                sz*ones(ns-ns_value)
            )
            fig_copy[:data][i][:marker][:line][:width]=vcat(
                zeros(ns_value - 1),
                lw,
                zeros(ns-ns_value)
            )
            fig_copy[:data][i][:marker][:opacity] = vcat(
                0.0*ones(max(0, ns_value-delay_value)),
                op*ones(min(ns_value-1, delay_value-1)), 
                1.0, 
                0.0*ones(ns-ns_value)
            )
            fig_copy[:data][i][:hovertemplate]=["Bus: $(sub_df[i,:labels]), NN: $(sub_df[i, NEIGHBOR_IND]), t: $(sub_df[i, :t])" for (i,l) in enumerate(sub_df[!,:labels])]
        else
            fig_copy[:data][i][:marker][:size] = sz*ones(length(fig_copy[:data][i][:x]))
            fig_copy[:data][i][:marker][:line][:width] = lw*ones(length(fig_copy[:data][i][:x]))
            fig_copy[:data][i][:marker][:lopacity] = op*ones(length(fig_copy[:data][i][:x]))
            fig_copy[:data][i][:hovertemplate]=["Bus: $(sub_df[i,:labels]), NN: $(sub_df[i, NEIGHBOR_IND]), t: $(sub_df[i, :t])" for (i,l) in enumerate(sub_df[!,:labels])]
        end
        fig_copy[:data][i][:visible] = i in bus
    end
    if n_bus < NUM_BUSES
        for i in 1:NUM_BUSES
            if i in (n_bus+1):NUM_BUSES
                fig_copy[:data][i][:visible] = false
            else
                fig_copy[:data][i][:visible] = true
            end
        end
    end
    return fig_copy
end

run_server(app, "0.0.0.0", 8001, debug = true)
