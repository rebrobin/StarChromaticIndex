# SageMath script for exploring reducible configurations.
# Input is a GeoGebra file.
# This script is designed for testing star chromatic index.

import geogebra_graph
import sys
import PrecoloringExtension
import itertools


if __name__=="__main__":

    num_colors=6
    
    if len(sys.argv)>1:
        file_input=sys.argv[1]
    else:
        file_input="3face_3face.ggb"
    
    print(f"Processing {file_input} with {num_colors} colors")
    
    G=geogebra_graph.geogebra_to_graph(file_input)
    geogebra_graph.geogebra_graph_plot(G).save(file_input+".pdf")
    
    # Color conventions:
    ### For edges:
    # Green are edges to extend the color to.
    # Magenta are edges to precolor and then recolor (need clone to extend color to).
    # Black is the default; the rest of the edges.
    ### For vertices:
    # We need some way to distinguish a 3-vertex with not all edges drawn from a 2-vertex.
    
    H=G.line_graph(labels=False)
        # we have stored extra edge information from GeoGebra as a dict in the edge label, and dicts are not hashable.  So we cannot keep the labels.
    
    # copy G's edge labels into H's vertex information.
    for e in H.vertices():
        H.set_vertex(e,G.edge_label(e[0],e[1]))

    
    # create the pos dictionary; each vertex of H will be at the midpoint of the edge in G.
    pos=dict()
    Gpos=G.get_pos()
    for e in H.vertices():
        pos[e]=(
            (Gpos[e[0]][0]+Gpos[e[1]][0])/2,
            (Gpos[e[0]][1]+Gpos[e[1]][1])/2)
    H.set_pos(pos)
    
    # Sort the vertices according to 
    extend_verts  =[v for v in H.vertices() if H.get_vertex(v)['color'][:3]==(0,255,0)]  # green vertices
    reducer_verts =[v for v in H.vertices() if H.get_vertex(v)['color'][:3]==(255,0,0)]  # red vertices
    recolor_verts =[v for v in H.vertices() if H.get_vertex(v)['color'][:3]==(255,0,255)]  # magenta vertices
    precolor_verts=[v for v in H.vertices() if v not in extend_verts and v not in reducer_verts and v not in recolor_verts]  # rest of vertices
    
    #print("extend_verts=",extend_verts)
    #print("reducer_verts=",reducer_verts)
    #print("recolor_verts=",recolor_verts)
    #print("precolor_verts=",precolor_verts)

    recolor_map={v:i+H.num_verts() for i,v in enumerate(recolor_verts)}
    #recolor_map=dict()
    #for i,e in enumerate(recolor_verts):
    #    recolor_map[e]=H.num_verts()+i
    recolored_verts=list(recolor_map.values())  # vertices that will receive a coloring, and hence need to be extended to
    H.add_vertices(recolored_verts)
    # edges within recolor_verts need to be cloned to recolored_verts
    for e in H.subgraph(recolor_verts).edges():
        #print(e)
        H.add_edge(recolor_map[e[0]],recolor_map[e[1]])
    for v,w in itertools.product(precolor_verts,recolor_verts):
        if H.has_edge(v,w):
            H.add_edge(v,recolor_map[w])
    for v,w in itertools.product(extend_verts,recolor_verts):
        if H.has_edge(v,w):
            H.delete_edge(v,w)
            H.add_edge(v,recolor_map[w])
    
    #print("extend_verts=",extend_verts)
    #print("reducer_verts=",reducer_verts)
    #print("recolor_verts=",recolor_verts)
    #print("precolor_verts=",precolor_verts)
    #print("recolored_verts=",recolored_verts)

    new_order=precolor_verts+recolor_verts+reducer_verts+extend_verts+recolored_verts  # the new order of the vertices
    new_permutation={v:i for i,v in enumerate(new_order)}
    H.relabel(perm=new_permutation,inplace=True)
    
    new_precolor_verts=list(range(len(precolor_verts)))
    new_recolor_verts=list(range(len(recolor_verts)+len(reducer_verts)))
    new_extend_verts  =list(range(len(new_precolor_verts)+len(new_recolor_verts),H.num_verts()))  # will include recolored vertices
    
    print(new_precolor_verts)
    print("new_recolor_verts",new_recolor_verts)
    print(new_extend_verts)
    #print(H.vertices())
    #print(new_order)
    #print(f"new_permutation={new_permutation}")

    #TODO: We can reorder precolor+recolor, but need to keep track of which is which. 
    #P=[]
    #while new_precolor_verts:
        #L=[]
        #for v in new_precolor_verts:
             #s=len([x for x in H.neighbors(v) if x in P])
             #L.append((s,v))
        #w=max(L)[1]
        #P.append(w)
        #new_precolor_verts.remove(w)
    
    #new_precolor_verts=P
    #new_order=new_precolor_verts+new_recolor_verts+new_extend_verts  # the new order of the vertices
    #new_permutation={v:i for i,v in enumerate(new_order)}
    #print("new_permutation=",new_permutation)
    #print(new_permutation.values())
    #H.relabel(perm=new_permutation,inplace=True)

    colors=dict()
    # plotted colors are named colors in matplotlib
    # https://matplotlib.org/3.1.0/gallery/color/named_colors.html
    colors[(0,255,0)]='springgreen'  # green in geogebra; vertices to extend coloring to
    colors[(255,0,0)]='salmon'  # red in geogebra; vertex and edge reducers
    colors[(0,255,255)]=other_v='skyblue'  # the rest of the vertices
    colors[(0,0,0)]=other_e='skyblue'  # the rest of the edges
    colors[(255,0,255)]='magenta'  # magenta in geogebra; vertices to recolor
    
    vertex_colors=dict()
    for color in colors.values():
        vertex_colors[color]=[]
    for v in H.vertices():
        if H.get_vertex(v):
            color_of_v=H.get_vertex(v)['color'][:3]
            if color_of_v in colors:
                vertex_colors[colors[color_of_v]].append(v)
            else:
                vertex_colors[other_v].append(v)
        else:
            vertex_colors[other_v].append(v)
    
    H.plot(vertex_colors=vertex_colors).save(file_input+'.line_graph.pdf')

    Result = PrecoloringExtension.check_precoloring_extension(H,len(new_precolor_verts),6,
       new_precolor_verts,new_recolor_verts,new_extend_verts)
    # Assumption: new_precolor_verts+new_recolor_verts is initial segment of the vertices.
    print(Result)


