
// C++ program to verify precoloring extension for star (vertex) chromatic number.

#include <vector>
#include <string>
#include <fstream>
#include <cstdio>


#ifdef USE128BITS
    typedef unsigned __int128 BIT_MASK;  // 128-bits, should work with both gcc and Clang
#else
    typedef unsigned long long int BIT_MASK;  // we want a 64-bit unsigned integer for bit masks
#endif


class cFourSetBlocker
// helper class for testing for violations of the star chromatic condition.
{
    // If c[cur]==c[same] and c[other1]==c[other2], this is a violation of the star chromatic condition.
public:
    int same;
    int other1,other2;
    
    cFourSetBlocker(int same,int other1,int other2)
        : same{same}, other1{other1}, other2{other2}
    { }
};


class cThreeSetBlocker
// helper class for testing for violations of the star chromatic condition.
{
    // If c[leaf]==type and c[other1]==c[other2], this is a violation of the star chromatic condition for the special case of leaves on tendrils.
public:
    int other1,other2;
    int leaf;
    int type;  // 2 for type T, 1 for type U
    
    cThreeSetBlocker(int leaf,int other1,int other2,int type)
        : leaf{leaf}, other1{other1}, other2{other2}, type{type}
    { }
};


class cProblemInstance
{
public:
    int n;  // number of vertices of the graph
    std::vector<BIT_MASK> adj_pred_mask;  // bit mask of adjacent predecessors for each vertex
    int num_colors;
    int num_precolored_verts;
    std::vector<std::vector<cFourSetBlocker> > FourSets;  // indexed by each vertex, gives the sets to check for the star chromatic condition on P4s and C4s.
    std::vector<std::vector<cThreeSetBlocker> > ThreeSets;  // indexed by each vertex, gives the sets to check for the star chromatic condition from leaves of tendrils.
    BIT_MASK tendril_leaves;  // bit array indicating which vertices are tendril leaves
    std::vector<int> SymmetryPair;  // array where SymmetryPair[cur] is the lesser-indexed vertex in a symmetry pair
    BIT_MASK symmetry_vertices;  // bit array indicating which vertices are the greater vertex in a symmetry pair
    
    // for parallelization
    int parallel_job_number;
    int parallel_num_jobs;
    int parallel_depth;
    
    cProblemInstance(std::string file_input,
                     int parallel_job_number,
                     int parallel_num_jobs,
                     int parallel_depth);
    
    bool verify_precoloring_extension();
};


cProblemInstance::cProblemInstance(
    std::string file_input,
    int parallel_job_number,
    int parallel_num_jobs,
    int parallel_depth)
    :  // initialization list
    parallel_job_number{parallel_job_number},
    parallel_num_jobs{parallel_num_jobs},
    parallel_depth{parallel_depth}
{
    std::string line;
    std::ifstream file_in(file_input);
    if (file_in.is_open())
        while (getline(file_in,line))
        {
            //printf("line: %s\n",line.c_str());
            
            if (line.rfind("n=",0)==0)
            {
                n=std::stoi(line.substr(2));
                adj_pred_mask.resize(n);  // initialize to be indexed by vertices
                FourSets.resize(n);  // initialize to be indexed by vertices
                ThreeSets.resize(n);  // initialize to be indexed by vertices
                tendril_leaves=0;
                SymmetryPair.resize(n);
                symmetry_vertices=0;
                printf("n=%d\n",n);
                if (n>sizeof(BIT_MASK)*8)
                {
                    printf("ERROR: n=%d is larger than BIT_MASK (%d bits)\n",n,sizeof(BIT_MASK)*8);
                    exit(99);
                }
            }
            else if (line.rfind("num_colors=",0)==0)
            {
                num_colors=std::stoi(line.substr(11));
                printf("num_colors=%d\n",num_colors);
            }
            else if (line.rfind("num_precolored_verts=",0)==0)
            {
                num_precolored_verts=std::stoi(line.substr(21));
                printf("num_precolored_verts=%d\n",num_precolored_verts);
            }
            else if (line.rfind("G=",0)==0)
            {
                std::string mapping("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz@#");
                // The first bit is the least significant bit.
                
                int pos=2;
                int value=0;  // 6-bit value
                int bits_left_in_value=0;
                int count=0;
                for (int j=0; j<n; ++j)
                    for (int i=0; i<j; ++i)
                    {
                        if (bits_left_in_value==0)
                        {
                            // We read in the next character and decode it.
                            value=mapping.find(line[pos]);
                            //printf("Read in character at pos=%d, value=%d\n",pos,value);
                            pos++;
                            bits_left_in_value=6;
                        }
                        
                        if ((value & 1)!=0)  // test whether the bottom bit is nonzero
                        {
                            // there is an edge between i and j.
                            adj_pred_mask[j]|=((BIT_MASK)1)<<i;
                            //printf("There is an edge between %2d and %2d\n",i,j);
                        }
                        
                        value>>=1;
                        bits_left_in_value--;
                    }
            }
            else if (line.rfind("B=",0)==0)  // four-vertex set blocker
            {
                int same1,same2,other1,other2;
                sscanf(line.substr(2).c_str(),
                    "%d,%d,%d,%d",&same1,&same2,&other1,&other2);
                // we assume same1>same2
                FourSets[same1].push_back(cFourSetBlocker(same2,other1,other2));
                //printf("There is a four-set blocker %d,%d and %d,%d\n",same1,same2,other1,other2);
            }
            else if (
                        // three-vertex set blocker from tendril
                     (line.rfind("T=",0)==0) ||
                     (line.rfind("U=",0)==0) 
                    )
            {
                int leaf,other1,other2,type;
                type=(line.rfind("T=",0)==0) ? 2 : 1;
                sscanf(line.substr(2).c_str(),
                    "%d,%d,%d",&leaf,&other1,&other2);
                // we assume other1>other2
                if (leaf>other1)
                    ThreeSets[leaf  ].push_back(cThreeSetBlocker(leaf,other1,other2,type));
                else
                    ThreeSets[other1].push_back(cThreeSetBlocker(leaf,other1,other2,type));
                printf("There is a three-set blocker; leaf:%d other:%d and %d  type=%d\n",leaf,other1,other2,type);
            }
            else if (line.rfind("L=",0)==0)  // tendril leaf
            {
                int leaf;
                sscanf(line.substr(2).c_str(),
                    "%d",&leaf);
                //printf("tendril leaf %d\n",leaf);
                tendril_leaves|=((BIT_MASK)1)<<leaf;
                //printf("tendril_leaves=%lx\n",tendril_leaves);
                if (leaf==0)
                {
                    printf("ERROR: cannot have vertex 0 be a leaf vertex\n");
                    // Because we never allow vertex 0 to be any color other than 1, it cannot be a leaf vertex.
                    exit(99);
                }
            }
            else if (line.rfind("S=",0)==0)  // symmetry pair
            {
                int pair1,pair2;
                sscanf(line.substr(2).c_str(),
                    "%d,%d",&pair1,&pair2);
                // we assume pair1<pair2
                printf("symmetry pair %d,%d\n",pair1,pair2);
                symmetry_vertices|=((BIT_MASK)1)<<pair2;
                SymmetryPair[pair2]=pair1;
            }
        }
    
    // no need to close the file, since the destructor automatically does this when the object goes out of scope.
}


bool cProblemInstance::verify_precoloring_extension()
    // should the parallelization parameters be parameters for this function?
{
    std::vector<int> c(n);  // assignment of colors; c[v] is the color assigned to vertex v.
    std::vector<int> prev_c(n);  // keeping previous assignment of colors, for output
    std::vector<BIT_MASK> color_mask(num_colors+1);  // bit mask of vertices with set color, for each color
    int cur=1;  // current vertex
    BIT_MASK cur_mask=2;  // a single bit set in the position corresponding to the current vertex, v
    
    const BIT_MASK mask_extended_vertices=(((BIT_MASK)1)<<(num_precolored_verts-1))-1;
            // a mask to clear the colors on vertices beyond the precolored vertices
            // also clear bit num_verts_to_precolor-1
    const BIT_MASK mask_first_n_bits=(((BIT_MASK)1)<<n)-1;
            // mask with first n positions set; used to test with cur_mask when cur<n
    const BIT_MASK mask_parallel_depth=((BIT_MASK)1)<<parallel_depth;
            // mask with bit set at parallel_depth; used to test when cur==parallel_depth
    
    
    c[0]=1;  // only color to check for vertex 0
    color_mask[1]|=((BIT_MASK)1)<<0;
    cur=1;
    cur_mask=2;
    c[cur]=2;  // first color to check
    
    unsigned long long int num_precolorings=0;
    int num_failures=0;
    
    long long int parallel_count=0;  // counts the number of search tree nodes encountered at depth parallel_depth
    
    bool backtrack;
    
    while (true)  // main loop
    {
        // we have just arrived at cur, and we need to find the *next* valid color for cur
        /*
        printf("\nStarting main loop, cur=%2d c=%d\n",cur,c[cur]);
        if (cur <= num_precolored_verts-12)
        {
            printf("cur=%2d num_precolorings=%19llu",cur,num_precolorings);
            for (int i=0; i<=cur; i++)
                printf(" %d:%d",i,c[i]);
            printf("\n");
        }
        //*/
        
        
        backtrack=true;
        
        while (c[cur])  // finding next color, this could be a valid color if it is positive
            // Note that we might start the while loop where c[cur] is already 0, in which case we want to backtrack.
            // We will use the colors 1..num_colors, and we count colors downward.
        {
            //printf("we have a candidate color for cur=%2d, c[cur]=%d\n",cur,c[cur]);
            
            // We test whether c[cur] is a valid color (ie, not on neighbors, star condition)
            
            if ((color_mask[c[cur]]&adj_pred_mask[cur])==0)  // we did not find this color c[cur] used in the neighborhood, so c[cur] is a valid color
            {
                // we now check the star coloring condition from four-vertex sets
                int j;
                for (j=FourSets[cur].size()-1; j>=0; j--)
                    if ((c[cur]==c[FourSets[cur][j].same]) &&
                        (c[FourSets[cur][j].other1]==c[FourSets[cur][j].other2]))
                        //TODO: possible optimization: have FourSets[cur] be a local reference
                        // c[cur] does not give a valid star coloring
                        break;  // break out of this for loop, and then continue the while loop to find the next color
                
                //printf("done checking star condition, j=%2d\n",j);
                if (j<0)
                {
                    // now need to check the three-vertex sets
                    for (j=ThreeSets[cur].size()-1; j>=0; j--)
                        if ((c[ThreeSets[cur][j].leaf] & ThreeSets[cur][j].type) &&
                            (c[ThreeSets[cur][j].other1]==c[ThreeSets[cur][j].other2]))
                            // c[cur] does not give a valid star coloring
                        {
                            /*
                            if (ThreeSets[cur][j].type==1)
                            printf("Violation of 3-sets: %d:%d %d:%d leaf %d:%d type %d\n",
                                ThreeSets[cur][j].other1,c[ThreeSets[cur][j].other1],
                                ThreeSets[cur][j].other2,c[ThreeSets[cur][j].other2],
                                ThreeSets[cur][j].leaf,  c[ThreeSets[cur][j].leaf],
                                ThreeSets[cur][j].type);
                            //*/
                            break;  // break out of this for loop, and then continue the while loop to find the next color
                        }
                    
                    if (j<0)
                        // no star coloring conditions were violated, so c[cur] is a good color.
                    {
                        backtrack=false;
                        break;  // out of while loop for finding next color
                    }
                }
            }
            
            // this color was no good, so we advance to the next color and start the loop again.
            c[cur]--;
            
        }  // while loop finding next color
        
        
        //printf("testing whether we should backtrack or not, cur=%d, backtrack=%d\n",cur,(int)backtrack);
        
        if (backtrack)
        {
            // no more left colors left for cur, so backtrack
            cur--;
            cur_mask>>=1;
            
            if (cur==num_precolored_verts-1)
                // we have backtracked to the last precolored vertex, so we have failed to extend this precoloring
            {
                num_failures++; // add one to the number of failures
                printf("We found a failure! Current number of failures is: %2d\n", num_failures);  // print how many failures have been found currently
                printf("cur=%2d ",cur);
                for (int i=0; i<num_precolored_verts; i++)
                    printf(" %d:%d",i,c[i]);
                printf("\n");
                if (num_failures>=100)
                {
                    printf("Number of failures is over %d, exiting.\n",num_failures);
                    printf("FAIL.  num_precolorings=%19llu\n",num_precolorings);
                    return false;  // stop when number of failures is over 100
                }
            }
            
            if (cur==0)  // we have backtracked to the first vertex and are done
                break;
            
            color_mask[c[cur]]^=cur_mask;  // clear the color mask
            c[cur]--;  // advance the color on cur
            continue;  // main while loop
        }
        else  // good color found, not backtracking, so we advance to the next vertex
        {
            // parallelization code
            if (cur_mask & mask_parallel_depth)  // cur==parallel_depth
            {
                parallel_count++;
                //printf("cur=%2d parallel_depth=%2d parallel_count=%5d parallel_num_jobs=%5d parallel_job_number=%5d\n",
                //    cur,parallel_depth,parallel_count,parallel_num_jobs,parallel_job_number);
                if ((parallel_count%parallel_num_jobs)!=parallel_job_number)
                {
                    // we do not continue examining this subtree of the search tree
                    //printf("parallel NOT continuing!\n");
                    c[cur]--;  // advance the color on cur
                    continue;  // main while loop
                }
                printf("Proceeding past parallel_depth=%d, parallel_count=%d\n",parallel_depth,parallel_count);
            }
            
            // set the color_mask
            color_mask[c[cur]]|=cur_mask;
            
            // move to next vertex
            cur++;
            cur_mask<<=1;
            
            
            if ((cur_mask & mask_first_n_bits)==0)  // cur>=n; we have colored all of the vertices
            {
                //printf("Hooray!  This precoloring extends! cur=%d\n",cur);
                
                num_precolorings++;  // note this only counts precolorings that extend
                if ((num_precolorings&0xffffff)==0)  //((num_precolorings&0xffffffff)==0)  // 32 bits set, roughly 1 billion
                {
                    printf("num_precolorings=%15llu",num_precolorings);
                    bool marker_placed=false;
                    for (int i=0; i<num_precolored_verts; i++)
                    {
                        if ((!marker_placed) && (c[i]!=prev_c[i]))
                        {
                            printf("+");  // indicates the least vertex whose color has changed since the last output
                            marker_placed=true;
                        }
                        else
                            printf(" ");
                        printf("%d:%d",i,c[i]);
                        prev_c[i]=c[i];
                    }
                    printf("\n");
                }
                
                cur=num_precolored_verts-1;  // go back to the last precolored vertex
                cur_mask=((BIT_MASK)1)<<cur;
                
                c[cur]--;  // advance the color on cur
                
                // we need to clear the color_masks for the vertices from cur to n, inclusive
                for (int i=num_colors; i>0; i--)
                    color_mask[i]&=mask_extended_vertices;  // this also clears cur's color
            }
            else
            {
                // We will be able to advance cur to the next vertex.
                // Now we need to set up the first color to try on that vertex.
                
                // put the first color to try on the new cur
                if (cur_mask&tendril_leaves)  // cur is a tendril leaf
                {
                    c[cur]=2;  // only two colors (2 and 1) for tendril leaves
                    //printf("cur=%d is a tendril leaf, only using 2 colors\n",cur);
                }
                else if (cur_mask&symmetry_vertices)  // cur is in a symmetry pair
                {
                    //printf("cur=%d is a symmetry pair of %d, so using fewer colors\n",cur,SymmetryPair[cur]);
                    if ((SymmetryPair[cur]<num_colors) &&
                        (c[SymmetryPair[cur]]==SymmetryPair[cur]+1))
                        //FIXME: this is probably not the best way to do this, but we probably need to calculate the largest used color at each step.
                        c[cur]=num_colors;  // just set to maximum
                            // complicated, since there might be 4 vertices in a symmetry "pair"
                    else
                        c[cur]=c[SymmetryPair[cur]]-1;  // the assumption is that the vertices in the symmetry pair are adjacent, or at least should not be the same.
                }
                else if (cur<num_colors)  // for vertex cur (which is 0-indexed), only use colors 1..cur+1.
                    c[cur]=cur+1;
                else
                    c[cur]=num_colors;  // for other vertices, use colors 1..num_colors.
            }
        }  // advancing to next vertex
        
    }  // main while loop
    
    printf("final parallel_count=%lld\n",parallel_count);
    if (num_failures>0)
        printf("FAIL.  num_precolorings=%19llu, num_failures=%d\n",num_precolorings,num_failures);
    else
        printf("Done.  num_precolorings=%19llu\n",num_precolorings);
    return true;
}


int main(int argc, char *argv[])
{
    if (argc<5)
    {
        printf("USAGE: ./star_precolor <file_input> <parallel_job_number> <parallel_num_jobs> <parallel_depth>\n");
        exit(1);
    }
    
    std::string file_input(argv[1]);
    int parallel_job_number=std::stoi(argv[2]);
    int parallel_num_jobs  =std::stoi(argv[3]);
    int parallel_depth     =std::stoi(argv[4]);
    
    printf("Reading file %s, job=%d, num_jobs=%d, depth=%d\n",
           file_input.c_str(),parallel_job_number,parallel_num_jobs,parallel_depth);
    
    cProblemInstance P(file_input,parallel_job_number,parallel_num_jobs,parallel_depth);
    if (P.verify_precoloring_extension())
        return 0;  // success
    else
        return 1;  // failure
}
