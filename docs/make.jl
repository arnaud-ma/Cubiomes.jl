using Documenter
using Cubiomes

makedocs(
    sitename = "Cubiomes",
    format = Documenter.HTML(),
    modules = [Cubiomes]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
