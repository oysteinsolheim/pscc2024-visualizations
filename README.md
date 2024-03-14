# pscc2024-visualizations
Install Julia version 1.7.3 and run
```
julia --project=@. -e "using Pkg; Pkg.instantiate()"
```
to install all dependencies and then 
```
julia --project plot_embeddings.jl
```
to start the dashboard.
