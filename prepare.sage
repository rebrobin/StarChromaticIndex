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
    #geogebra_graph.geogebra_graph_plot(G).save(file_input+".pdf")
    
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
    vertices_incident_to_extend_edges=[]
    for e in G.edges():
        if G.edge_label(e[0],e[1])['color'][:3] in [(0,255,0),(255,0,255)]:  # green or magenta vertices
            vertices_incident_to_extend_edges+=e[:2]
    
    pos={v:np.array(p) for v,p in G.get_pos().items()}
    # compute the center of the picture
    center=np.average(np.array([pos[v] for v in G.vertices()]),axis=0)
    # compute the average length of an edge
    avg_edge_length=np.average(np.array([
                    np.linalg.norm(pos[u]-pos[v]) for u,v,_ in G.edges()
                    ]))
    
    default_edge_label={'color':(0,0,0),'style':0}
    default_vertex_info={'color':(0,255,255),'style':0}
    
    def compute_pos(root,length,rotation):
        # we assume that root is a vector, length a scalar, and rotation is a scalar
        offset=(root-center)/np.linalg.norm(root-center)  # unit vector in the direction
        theta=np.deg2rad(rotation*30)
        rot_matrix=np.array([[np.cos(theta),-np.sin(theta)],[np.sin(theta),np.cos(theta)]])
        offset=rot_matrix.dot(offset)  # rotate the offset
        return root+offset*length
    
    VG=list(G.vertices())  # make list beforehand, since vertices might be added.
    G_no_reducer_edges=G.subgraph(vertices=None,  # all the vertices
        edge_property=lambda e: e[2]['color'][:3]!=(255,0,0))  # no red edges
    
    tendril_leaves=[]
    tendril_branches=[]
    tendril_stems=[]
    for v in VG:
        if G.get_vertex(v)['style']==1:  # style 1 is x
            continue  # do not add any tendrils; leave alone
        
        if G.get_vertex(v)['style']==4:  # style 4 is diamond
            target_degree=2
        else:  # default style 0 is colored circle
            target_degree=3
        
        # we need to add a tendril to this vertex; but how big a tendril?
        # The size depends on the shortest distance to a green or magenta edge.
        d=min(G.distance(v,x) for x in vertices_incident_to_extend_edges)
        print(f"{v=} deg={G.degree(v)} {d=}")
        
        if d<=2:  # tendril needed
            num_verts_to_add=target_degree-G_no_reducer_edges.degree(v)  # num verts to add to make degree 3
            
            stems=list(range(G.num_verts(),G.num_verts()+num_verts_to_add))
            print(f"adding {stems=}")
            stem_edges=[]
            for i,s in enumerate(stems):
                G.add_vertex(s)
                G.set_vertex(s,default_vertex_info)
                G.add_edge(v,s,default_edge_label)
                stem_edges.append(tuple(sorted([v,s])))
                pos[s]=compute_pos(pos[v],avg_edge_length*.9,i*num_verts_to_add-1)
            if len(stems)==2:
                tendril_stems.append(stem_edges)
            
            if d<=1:  # add another layer
                branch_edges=[]  # when 2 stems, add all the branches
                for s in stems:
                    num_verts_to_add=2-d  # we don't need 2 vertices if this is the last level
                    branches=list(range(G.num_verts(),G.num_verts()+num_verts_to_add))
                    print(f"adding {branches=}")
                    for i,b in enumerate(branches):
                        G.add_vertex(b)
                        G.set_vertex(b,default_vertex_info)
                        G.add_edge(s,b,default_edge_label)
                        branch_edges.append(tuple(sorted([s,b])))
                        pos[b]=compute_pos(pos[s],avg_edge_length*.9,i*num_verts_to_add-1)
                    
                    if d<=0:  # add another layer
                        for b in branches:
                            leaves=list(range(G.num_verts(),G.num_verts()+1))  # only need to add 1 leaf vertex to each branch at this level
                            print(f"adding {leaves=}")
                            for i,l in enumerate(leaves):
                                G.add_vertex(l)
                                tendril_leaves.append(l)
                                G.set_vertex(l,default_vertex_info)
                                G.add_edge(b,l,default_edge_label)
                                pos[l]=compute_pos(pos[b],avg_edge_length*.8,0)
                
                if branch_edges:  # not empty
                    tendril_branches.append(branch_edges)  # add all branches for these stems
    
    print(f"{tendril_leaves=}")
    print(f"{tendril_branches=}")
    print(f"{tendril_stems=}")
    G.set_pos(pos)
    
    geogebra_graph.geogebra_graph_plot(G).save(file_input+".pdf")
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
    
    # Classify the vertices according to color
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
    print(f"{new_order=}")
    tendril_leaves=[new_permutation[v] for v in new_order 
                    if isinstance(v,tuple) and 
                       (v[0] in tendril_leaves or v[1] in tendril_leaves)]
    print(f"{tendril_leaves=}")
    tendril_branches=[
            tuple([new_permutation[v] for v in branch_edges])
            for branch_edges in tendril_branches]
    print(f"{tendril_branches=}")
    tendril_stems=[
            tuple([new_permutation[v] for v in stem_edges])
            for stem_edges in tendril_stems]
    print(f"{tendril_stems=}")
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

    if True:
        # We reorder all_precolor_verts+all_reducer_verts, but need to keep track of which is which.
        S=copy(all_precolor_verts)+copy(all_reducer_verts)  # reorder these vertices
        P=[]  # new order of the vertices
        while S:
            L=[]
            for v in S:
                s=len([x for x in H.neighbors(v) if x in P])  # number of neighbors already colored
                if len(P)==0 and v in tendril_leaves:
                    pass  # the first vertex cannot be a tendril leaf
                else:
                    L.append((s,v))  # sort by number of precolored nbrs
            w=max(L)[1]
            P.append(w)
            S.remove(w)
        
        if P[0] in tendril_leaves:
            print(f"ERROR: a tendril leaf cannot be vertex 0")
            exit(99)
        
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
    else:
        # no re-ordering
        P=all_precolor_verts+all_reducer_verts+all_extend_verts
    
    reordered_precolor_verts=[P.index(v) for v in all_precolor_verts]
    reordered_reducer_verts =[P.index(v) for v in all_reducer_verts]
    new_permutation={v:i for i,v in enumerate(P)}
    tendril_leaves=[new_permutation[v] for v in tendril_leaves]
    print(f"{tendril_leaves=}")
    tendril_branches=[
            tuple(sorted([new_permutation[v] for v in branch_edges]))
            for branch_edges in tendril_branches]
    print(f"{tendril_branches=}")
    tendril_stems=[
            tuple(sorted([new_permutation[v] for v in stem_edges]))
            for stem_edges in tendril_stems]
    print(f"{tendril_stems=}")
    H.relabel(perm=new_permutation,inplace=True)
    
    if file_input=="1vertex_distance3.ggb":
        tendril_leaves=[10,11,14,15,20,21,24,25,30,31,34,35,40,41,44,45]
        tendril_branches=[(6,7),(8,9),(12,13),(16,17),(18,19),(22,23),(26,27),(28,29),(32,33),(36,37),(38,39),(42,43)]
    elif file_input=="1vertex_distance4a.ggb":
        # add additional symmetries
        tendril_stems.extend([(3,7),(8,9),(12,13),(10,11),(2,4),(5,6)])  # do not include (0,1) since 0 does not change
    
    
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
    
    # for tendrils:
    if False:
        # NOTE: We actually can't do this here, because we need the edges to find the P4s.
        # delete the incident edges
        for e in list(H.edges()):
            for v in tendril_leaves:
                if v in e:
                    H.delete_edge(e)
    
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
                if (i not in tendril_leaves and j not in tendril_leaves) and H.has_edge(i,j):
                    value|=mask
                    print(f"H has an edge between {i:2} and {j:2} {mask=:2}")
                mask<<=1
                if (mask & possible_bits)==0:  # 6 bits have been filled in
                    # Add the mapped value to the string.
                    s+=mapping[value]
                    value=0
                    mask=1
        if mask!=1:  # are there bits remaining in value that were not outputted?
            s+=mapping[value]
        f.write(s+"\n")
        
        # do some preprocessing for star vertex coloring
        PC=[[] for i in range(H.num_verts())]
        TB=set([x for X in tendril_branches for x in X])
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
                
                intersection_size=len(set(S)&set(tendril_leaves))
                if intersection_size>=2:
                    #print(f"{S=} contains >=2 tendril leaves!")
                    pass
                elif intersection_size==1:
                    print(f"{S=} contains 1 tendril leaf!")
                    leaf=list(set(S)&set(tendril_leaves))[0]
                    if leaf in N:
                        must_be_equal=other+[cur]
                    else:
                        must_be_equal=N
                    print(f"{must_be_equal=} {leaf=}")
                    max_equal,min_equal=max(must_be_equal),min(must_be_equal)
                    f.write(f"T={leaf},{max_equal},{min_equal}\n")
                else:  # no tendril leaves
                    if len(set(S)&TB)==1:
                        for v in set(S)&TB:  # tendril branch vertex
                            leaf=[x for x in H.neighbors(v) if x in tendril_leaves][0]  # tendril leaf
                            print(f"{S=} has one tendril branch, {v=} {leaf=}")
                            if v in N:
                                must_be_equal=other+[cur]
                            else:
                                must_be_equal=N
                            print(f"{must_be_equal=} {v=} {leaf=}")
                            max_equal,min_equal=max(must_be_equal),min(must_be_equal)
                            f.write(f"U={leaf},{max_equal},{min_equal}\n")
                            break
                    else:
                        f.write(f"B={cur},{other[0]},{N[0]},{N[1]}\n")
        
        # give list of tendril leaves
        for v in tendril_leaves:
            f.write(f"L={v}\n")
        
        # give list of tendril branches+stems
        for B in tendril_branches+tendril_stems:
            print(f"symmetry {B}")
            # S for symmetry; we assume two vertices; in increasing order
            for i in range(len(B)-1):
                f.write(f"S="+(','.join([str(x) for x in B[i:i+2]]))+"\n")
        
