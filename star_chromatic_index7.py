#!/usr/bin/env python

from __future__ import print_function

from sage.all import *   # import sage library

import itertools
import sys

try:
    p=MixedIntegerLinearProgram(solver='CPLEX')
    solver='CPLEX'
except:
    solver='GLPK'
print("Using IP solver %s" % solver)


def is_scn_at_most(G,k):
    '''Compute whether the star chromatic numer (vertex version) of G is at most k.'''
    colors=list(range(k))
    p=MixedIntegerLinearProgram(solver=solver)
    x=p.new_variable(binary=True,name='x')  # x[v,c]=1 iff vertex v is colored c
    
    # every vertex is colored with exactly one color
    for v in G.vertices():
        p.add_constraint(p.sum(x[v,c] for c in colors)==1)
    
    # every edge is not monochromatic
    for u,v,_ in G.edges():
        for c in colors:
            p.add_constraint(x[u,c]+x[v,c]<=1)
    
    PC=[]
    for S in itertools.combinations(G.vertices(),4):
        H=G.subgraph(vertices=S)
        if ((H.num_edges()==4 and H.degree_sequence()==[2,2,2,2]) or
            (H.num_edges()==3 and H.degree_sequence()==[2,2,1,1])):
            # H is an induced path or an induced cycle on 4 vertices.
            #print(S)
            PC.append(S)
    #print(f"size of PC={len(PC)}")

    # For each S in PC, each pair of colors can only be used on at most 3 vertices of S.
    for S in PC:
        for c1,c2 in itertools.combinations(colors,2):
            p.add_constraint(p.sum(x[v,c1]+x[v,c2] for v in S)<=3)
    
    # fix colors on two adjacent vertices
    for u,v,_ in G.edges():
        p.add_constraint(x[u,0]==1)
        p.add_constraint(x[v,1]==1)
        break
    
    #p.show()
    
    try:
        p.solve()
        return True
        phi=dict()
        for v in G.vertices():
            for c in colors:
                if p.get_values(x[v,c])>.9:
                    phi[v]=c
        return phi
    except: # MIPSolverException:
        return False


if __name__=="__main__":

    if len(sys.argv)<4:
        print("USAGE: n res mod")
        exit(4)
    
    n=int(sys.argv[1])
    res=int(sys.argv[2])
    mod=int(sys.argv[3])

    print("==> Starting to check n=%d res=%d mod=%d" % (n,res,mod))
    count=-1
    nonminimal_count=0
    for count,G in enumerate(graphs.nauty_geng(options=str(n)+' -C -d2 -D3 %d/%d' % (res,mod))):
        # 2-connected graphs, minimum degree 2, maximum degree 3
        if count%100==0:
            print("   --- Count is",count)
        
        nonminimal=False
        for v in G.vertices():
            if G.degree(v)==2:
                for u in G.neighbors(v):
                    if G.degree(u)!=2:
                        break  # u loop
                else:  # both neighbors of v have degree 2
                    nonminimal=True
                    break  # v loop
        if nonminimal:
            nonminimal_count+=1
            print("nonminimal example",nonminimal_count,G.graph6_string())
            continue  # G loop
        
        L=G.line_graph()
        if not is_scn_at_most(L,k=5):
            print(">5: n=%d count=%d" % (n,count))
            if not is_scn_at_most(L,k=6):
                print(">6: n=%d count=%d COUNTEREXAMPLE" % (n,count))
            print('GRAPH:',G.graph6_string())
            #G.show()
    
    print("    Done with n=%d, total count=%d" % (n,count+1))

