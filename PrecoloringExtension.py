#!/usr/bin/env python
# coding: utf-8

import itertools
from sage.all import *

def check_precoloring_extension(G,num_precolored_verts,num_colors,precolor_verts=[],recolor_verts=[],extend_verts=[],
                                parallel_job_number=0,parallel_num_jobs=100,parallel_depth=3):
    # vertex coloring; we precolor vertices 0..num_precolored_verts-1, and then extend.
    # For parallelization: parallel_depth<=num_precolored_verts, 0<=parallel_job_number<parallel_num_jobs
    
    #print(num_precolored_verts, num_colors, precolor_verts, recolor_verts, extend_verts)
    
    # do some preprocessing for star vertex coloring
    PC=[[] for i in range(G.num_verts())]
    for S in itertools.combinations(G.vertices(),4):
        if len(set(S) & set(recolor_verts))>0  and len(set(S) & set(extend_verts))>0:
            continue  # we cannot mix recolor_verts and extend_verts in a P4 or C4.
        H=G.subgraph(vertices=S)
        if ((H.num_edges()==4 and H.degree_sequence()==[2,2,2,2]) or
            (H.num_edges()==3 and H.degree_sequence()==[2,2,1,1])):
            # H is an induced path or an induced cycle on 4 vertices.
            cur=max(S)
            if H.degree(cur)==1:
                N=list(H.neighbors(cur))+[x for x in S if x!=cur and H.degree(x)==1]
            else:
                N=list(H.neighbors(cur))
            other=list(set(S)-set(N)-set([cur]))
            #print(f"cur={cur} N={N} other={other} S={S}", H.num_edges(), H.degree_sequence())
            #G.plot().save('G.pdf')
            #exit()
            PC[cur].append((N[0],N[1],other[0]))
    
    c=[None]*G.num_verts()  # assignment of colors; c[v] is the color assigned to vertex v.
    cur=0  # current vertex
    c[cur]=-1
    num_failures=0
    
    num_precolorings=0
    parallel_count=0  # counts the number of search tree nodes encountered at depth parallel_depth
    while cur>=0:
        # we have just arrived at cur, and we need to find the next valid color for cur
        #print(f"{cur=} {c=}")
        if cur <= num_precolored_verts-7:
            print(cur,c)
        
        backtrack=False
        while True:  # finding next color
            c[cur]+=1
            if c[cur]>=num_colors or c[cur]>cur:
                # no more left colors left for cur, so backtrack
                cur-=1
                
                if cur==num_precolored_verts-1:  # we are going to backtrack to the last precolored vertex, so we have failed to extend this precoloring
                    num_failures=num_failures+1 #add one to the number of failures
                    if num_failures >= 100:
                        print("Number of failures is over", num_failures)
                        return False #stop when number of failures is over 100
                    print("We found a failure! Current number of failures is:", num_failures, "The coloring is", c) #print how many failures have been found currently
                
                backtrack=True
                break  # while loop for finding next color
            
            for v in G.neighbors(cur):
                if v>cur:
                    continue
                if c[v]==c[cur]:  # c[cur] is not a valid color
                    break  # for loop of neighbors
            else:  # we did not find this color c[cur] used in the neighborhood, so c[cur] is a valid color
                
                # we now check the star coloring condition
                for u,v,other in PC[cur]:
                    #print(f"{cur=} {u=} {v=} {other=} {c=}")
                    if c[u]==c[v] and c[cur]==c[other]:  # c[cur] does not give a valid star coloring
                        break  # break out of this loop, and then continue the while loop to find the next color
                else:
                    # no star coloring conditions were violated
                    break  # while loop for finding next color
        
        if backtrack:
            continue  # outer while loop for moving cur
        else:  # not backtracking, so we advance to the next vertex
            cur+=1
            
            if cur==num_precolored_verts:
                num_precolorings+=1
            
            if cur>=G.num_verts():  # we have colored all of the vertices
                #print("Hooray!",c)  # we have found an extension of this precoloring
                cur=num_precolored_verts-1  # go back to the last precolored vertex
                for i in range(cur+1,G.num_verts()):
                    c[i]=None
            else:
                if cur==parallel_depth:
                    parallel_count+=1
                    print(f"cur={cur}, parallel_depth={parallel_depth} parallel_count={parallel_count}, parallel_num_jobs={parallel_num_jobs} parallel_job_number={parallel_job_number}")
                    if parallel_count%parallel_num_jobs!=parallel_job_number:
                        # we do not continue examining this subtree of the search tree
                        #print("parallel NOT continuing!")
                        cur-=1
                        continue
                c[cur]=-1
    print(f"num_precolorings={num_precolorings}")
    return True


if __name__=="__main__":
    
    print("Starting check of precoloring extension")
    #result=check_precoloring_extension(
        #G=Graph('TpKOgOHOA?_A?D?@??g?C??c?G@?OG?oG_?F'),
        #num_precolored_verts=17,
        #num_colors=6,
        #precolor_verts=[10, 9, 2, 4, 3, 12, 11, 16, 15, 14, 13, 8, 7, 6, 5],
        #recolor_verts=[1, 0],
        #extend_verts=[17, 18, 19, 20],
        #parallel_job_number=0,parallel_num_jobs=2,parallel_depth=10,
        #)
    result=check_precoloring_extension(
        G=Graph('IxKOgGDA_'),
        num_precolored_verts=9,
        num_colors=6,
        precolor_verts=[4, 6, 3, 2, 5, 8, 7, 1, 0],
        recolor_verts=[],
        extend_verts=[9],
        parallel_job_number=1,parallel_num_jobs=2,parallel_depth=5,
        )

