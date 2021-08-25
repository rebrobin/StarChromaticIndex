# SageMath script for exploring reducible configurations.
# Input is a GeoGebra file.
# This script is designed for testing star chromatic index.

import geogebra_graph
import sys
import itertools
import numpy as np
from pathlib import Path


if __name__=="__main__":

    num_colors=6
    
    if len(sys.argv)>1:
        file_input=sys.argv[1]
    else:
        file_input="3face_2vertex.ggb"
    
    print(f"Processing {file_input} with {num_colors} colors")
    
    G=geogebra_graph.geogebra_to_graph(file_input)
    geogebra_graph.geogebra_graph_plot(G).save(file_input+".pdf")
    
    # Color/style conventions from the GeoGebra file:
    # Points become vertices, and line segments become edges.
    ### For edges:
    # Green are edges to extend the color to.
    # Magenta are edges to precolor and then recolor (need clone to extend color to).
    # Red are edges that are reducers (constrain the precoloring).
    # Black is the default; the rest of the edges.
    ### For vertices:
    # We need some way to distinguish a 3-vertex with not all edges drawn from a 2-vertex.
    
    
    ### Add tendrils as necessary.
    VG=list(G.vertices())  # make list beforehand, since vertices might be added.
    for v in VG:
        continue
        if G.degree(v)<2:
            print(f"Something is wrong with the degree of vertex {v}!")
            exit(5)
        elif G.degree(v)==2:
            if G.get_vertex(v)['style']>0:  # style 0 is colored circle; style 4 is diamond
                continue
            # we need to add a tendril to this vertex; but how big a tendril?
            # The size depends on the shortest distance to a green or magenta edge.
            #TODO: To think about.
    
    #exit(5)
    
    H=G.line_graph(labels=False)
        # we have stored extra edge information from GeoGebra as a dict in the edge label, and dicts are not hashable.  So we cannot keep the labels.
    
    # copy G's edge labels into H's vertex information.
    for e in H.vertices():
        H.set_vertex(e,G.edge_label(e[0],e[1]))
    
    # create the pos dictionary; each vertex of H will be at the midpoint of the edge in G.
    pos=dict()
    Gpos=G.get_pos()
    for e in H.vertices():
        pos[e]=np.array((
            (Gpos[e[0]][0]+Gpos[e[1]][0])/2,
            (Gpos[e[0]][1]+Gpos[e[1]][1])/2))
    H.set_pos(pos)
    
    # compute the center of the picture
    center=np.average(np.array([pos[v] for v in H.vertices()]),axis=0)
    # compute the average length of an edge
    avg_edge_length=np.average(np.array([
                    np.linalg.norm(pos[u]-pos[v]) for u,v,_ in H.edges()
                    ]))
    
    # Sort the vertices according to 
    extend_verts  =[v for v in H.vertices() if H.get_vertex(v)['color'][:3]==(0,255,0)]  # green vertices
    reducer_verts =[v for v in H.vertices() if H.get_vertex(v)['color'][:3]==(255,0,0)]  # red vertices
    recolor_verts =[v for v in H.vertices() if H.get_vertex(v)['color'][:3]==(255,0,255)]  # magenta vertices
    precolor_verts=[v for v in H.vertices() if v not in extend_verts and v not in reducer_verts and v not in recolor_verts]  # rest of vertices
    
    print("extend_verts=",extend_verts)
    print("reducer_verts=",reducer_verts)
    print("recolor_verts=",recolor_verts)
    print("precolor_verts=",precolor_verts)

    recolor_map={v:i+H.num_verts() for i,v in enumerate(recolor_verts)}
    recolored_verts=list(recolor_map.values())  # vertices that will receive a coloring, and hence need to be extended to
    
    H.add_vertices(recolored_verts)
    for v in recolor_verts:
        w=recolor_map[v]
        vertex_info={'color':(200,30,200,0)}  # mauve color
        H.set_vertex(w,vertex_info)
        vec=(pos[v]-center)
        vec/=np.linalg.norm(vec)  # make a unit vector
        pos[w]=pos[v]+vec*avg_edge_length/3
    H.set_pos(pos)
    
    # edges within recolor_verts need to be cloned to recolored_verts
    for e in H.subgraph(recolor_verts).edges():
        H.add_edge(recolor_map[e[0]],recolor_map[e[1]])
    # edges from precolor_verts to recolor_verts need to be cloned to recolored_verts
    for v,w in itertools.product(precolor_verts,recolor_verts):
        if H.has_edge(v,w):
            H.add_edge(v,recolor_map[w])
    # edges between extend_verts and recolor_verts need to be moved to recolored_verts
    for v,w in itertools.product(extend_verts,recolor_verts):
        if H.has_edge(v,w):
            H.delete_edge(v,w)
            H.add_edge(v,recolor_map[w])
    # there are no edges between reducer_verts and recolored_verts
    
    # we delete edges between extend_verts and reducer_verts
    for v,w in itertools.product(extend_verts,reducer_verts):
        if H.has_edge(v,w):
            H.delete_edge(v,w)
    
    new_order=(precolor_verts
               +recolor_verts+reducer_verts
               +extend_verts+recolored_verts)  # the new order of the vertices
    new_permutation={v:i for i,v in enumerate(new_order)}
    H.relabel(perm=new_permutation,inplace=True)
    
    # We now create the lists of vertices.
    # Where they came from doesn't matter, just their role now: precolor, reducer, extend
    all_precolor_verts=list(range(len(precolor_verts)))
    all_reducer_verts =list(range(len(all_precolor_verts),
                                  len(all_precolor_verts)+
                                  len(recolor_verts)
                                  +len(reducer_verts)))
    all_extend_verts  =list(range(len(all_precolor_verts)+len(all_reducer_verts),
                                  H.num_verts()))  # will include recolored vertices
    
    print(f"{all_precolor_verts=}")
    print(f"{all_reducer_verts=}")
    print(f"{all_extend_verts=}")

    # We reorder all_precolor_verts+all_reducer_verts, but need to keep track of which is which.
    S=copy(all_precolor_verts)+copy(all_reducer_verts)  # reorder these vertices
    P=[]  # new order of the vertices
    while S:
        L=[]
        for v in S:
             s=len([x for x in H.neighbors(v) if x in P])  # number of neighbors already colored
             L.append((s,v))
        w=max(L)[1]
        P.append(w)
        S.remove(w)
    
    # Now reorder all_extend_verts.
    S=copy(all_extend_verts)
    while S:
        L=[]
        for v in S:
             s=len([x for x in H.neighbors(v) if x in P])  # number of neighbors already colored
             L.append((s,v))
        w=max(L)[1]
        P.append(w)
        S.remove(w)
    
    reordered_precolor_verts=[P.index(v) for v in all_precolor_verts]
    reordered_reducer_verts =[P.index(v) for v in all_reducer_verts]
    new_permutation={v:i for i,v in enumerate(P)}
    H.relabel(perm=new_permutation,inplace=True)
    
    colors=dict()
    # plotted colors are named colors in matplotlib
    # https://matplotlib.org/3.1.0/gallery/color/named_colors.html
    colors[(0,255,0)]='springgreen'  # green in geogebra; vertices to extend coloring to
    colors[(255,0,0)]='salmon'  # red in geogebra; vertex and edge reducers
    colors[(0,255,255)]=other_v='skyblue'  # the rest of the vertices
    colors[(0,0,0)]=other_e='skyblue'  # the rest of the edges
    colors[(255,0,255)]='magenta'  # magenta in geogebra; vertices to recolor
    colors[(200,30,200)]='mediumvioletred'  # magenta in geogebra; recolored vertices (ie, the extend to)
    
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
    
    print()
    print(f"{reordered_precolor_verts=}")
    print(f"{reordered_reducer_verts=}")
    print(f"{all_extend_verts=}")
    
    filename_output=Path(file_input).with_suffix(".txt")  # change suffix
    
    with open(filename_output,'wt') as f:
        f.write(f"> Input file for {file_input}\n")
        f.write(f"n={H.num_verts()}\n")
        f.write(f"num_colors={num_colors}\n")
        f.write(f"num_precolored_verts={len(reordered_precolor_verts)+len(reordered_reducer_verts)}\n")
        
        mapping="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz@#";
        # The first bit is the least significant bit.
        s='G='
        value=0;  # 6-bit value
        mask=1;  # mask of where to put the value
        possible_bits=(1<<6)-1  # possible bit positions
        for j in range(H.num_verts()):
            for i in range(j):
                if H.has_edge(i,j):
                    value|=mask
                mask<<=1
                if H.has_edge(i,j):
                    print(f"H has an edge between {i:2} and {j:2} {mask=:2}")
                if (mask & possible_bits)==0:  # 6 bits have been filled in
                    # Add the mapped value to the string.
                    s+=mapping[value]
                    value=0
                    mask=1
        f.write(s+"\n")
        
        # do some preprocessing for star vertex coloring
        PC=[[] for i in range(H.num_verts())]
        for S in itertools.combinations(H.vertices(),4):
            if ( len(set(S) & set(reordered_reducer_verts))>0 and
                 len(set(S) & set(all_extend_verts))>0 ):
                continue  # we cannot mix reducer_verts and extend_verts in a P4 or C4.
            F=H.subgraph(vertices=S)
            if ((F.num_edges()==4 and F.degree_sequence()==[2,2,2,2]) or
                (F.num_edges()==3 and F.degree_sequence()==[2,2,1,1])):
                # F is an induced path or an induced cycle on 4 vertices.
                cur=max(S)
                if F.degree(cur)==1:
                    N=list(F.neighbors(cur))+[x for x in S if x!=cur and F.degree(x)==1]
                else:
                    N=list(F.neighbors(cur))
                other=list(set(S)-set(N)-set([cur]))
                f.write(f"B={cur},{other[0]},{N[0]},{N[1]}\n")
