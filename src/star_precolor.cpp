
// C++ program to verify precoloring extension for star (vertex) chromatic number.

#include <vector>
#include <string>
#include <fstream>
#include <cstdio>


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


class cProblemInstance
{
public:
    int n;  // number of vertices of the graph
    std::vector<std::vector<int> > adj_pred;  // list of adjacent predecessors for each vertex
    int num_colors;
    int num_precolored_verts;
    std::vector<std::vector<cFourSetBlocker> > FourSets;  // indexed by each vertex, gives the sets to check for the star chromatic condition on P4s and C4s.
    
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
                adj_pred.resize(n);  // initialize to be indexed by vertices
                FourSets.resize(n);  // initialize to be indexed by vertices
                printf("n=%d\n",n);
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
                            adj_pred[j].push_back(i);
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
        }
    
    // no need to close the file, since the destructor automatically does this when the object goes out of scope.
}


bool cProblemInstance::verify_precoloring_extension()
    // should the parallelization parameters be parameters for this function?
{
    std::vector<int> c(n);  // assignment of colors; c[v] is the color assigned to vertex v.
    int cur=0;  // current vertex
    c[cur]=2;  // color not yet assigned to cur
    
    unsigned long long int num_precolorings=0;
    int num_failures=0;
    
    int parallel_count=0;  // counts the number of search tree nodes encountered at depth parallel_depth
    
    bool backtrack=false;
    
    while (cur>=0)  // main loop
    {
        // we have just arrived at cur, and we need to find the next valid color for cur
        //printf("\nStarting main loop, cur=%2d c=%d\n",cur,c[cur]);
        if (cur <= num_precolored_verts-12)
        {
            printf("cur=%2d num_precolorings=%19llu",cur,num_precolorings);
            for (int i=0; i<=cur; i++)
                printf(" %d:%d",i,c[i]);
            printf("\n");
        }
        
        backtrack=false;
        
        while (true)  // finding next color
            // We will use the colors 1..num_colors, and we count colors downward.
        {
            //printf("finding next color, cur=%d, c[cur]=%d\n",cur,c[cur]);
            c[cur]--;
            if (c[cur]==0)
//             if ((c[cur]>=num_colors) ||
//                 (c[cur]>cur))  // this is an optimization to remove redundancy when permuting color names
            {
                // no more left colors left for cur, so backtrack
                cur--;
                
                if (cur==num_precolored_verts-1)
                    // we are going to backtrack to the last precolored vertex, so we have failed to extend this precoloring
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
                
                backtrack=true;
                break;  // out of while loop for finding next color
            }
            
            //printf("we have a candidate color for cur=%2d, c[cur]=%d\n",cur,c[cur]);
            
            int j;
            for (j=adj_pred[cur].size()-1; j>=0; j--)
                // loop through the neighbors that have already been colored
            {
                //printf("checking neighbors: cur=%d, c[cur]=%d, j=%d, adj_pred[cur][j]=%d, c=%d\n",cur,c[cur],j,adj_pred[cur][j],c[adj_pred[cur][j]]);
                if (c[adj_pred[cur][j]]==c[cur])  // c[cur] is not a valid color
                    break;
            }
            
            //printf("done checking neighbors' colors, j=%2d\n",j);
            
            if (j<0)  // we did not find this color c[cur] used in the neighborhood, so c[cur] is a valid color
            {
                // we now check the star coloring condition
                for (j=FourSets[cur].size()-1; j>=0; j--)
                    if (c[cur]==c[FourSets[cur][j].same] &&
                        c[FourSets[cur][j].other1]==c[FourSets[cur][j].other2])
                        //TODO: possible optimization: have FourSets[cur] be a local reference
                        // c[cur] does not give a valid star coloring
                        break;  // break out of this for loop, and then continue the while loop to find the next color
                
                //printf("done checking star condition, j=%2d\n",j);
                if (j<0)
                    // no star coloring conditions were violated, so c[cur] is a good color.
                    break;  // out of while loop for finding next color
            }
            
        }  // while loop finding next color
        
        //printf("testing whether we should backtrack or not, cur=%d, backtrack=%d\n",cur,(int)backtrack);
        
        if (backtrack)
            continue;  // outer while loop for moving cur
        else  // not backtracking, so we advance to the next vertex
        {
            cur++;
            
            if (cur==num_precolored_verts)
                num_precolorings++;
            
            if (cur>=n)  // we have colored all of the vertices
            {
                //printf("Hooray!  This precoloring extends! cur=%d\n",cur);
                cur=num_precolored_verts-1;  // go back to the last precolored vertex
                for (int i=cur+1; i<n; i++)
                    c[i]=-1;  // unassign the colors beyond cur
            }
            else
            {
                if (cur==parallel_depth)
                {
                    parallel_count++;
                    printf("cur=%2d parallel_depth=%2d parallel_count=%5d parallel_num_jobs=%5d parallel_job_number=%5d\n",
                           cur,parallel_depth,parallel_count,parallel_num_jobs,parallel_job_number);
                    if ((parallel_count%parallel_num_jobs)!=parallel_job_number)
                    {
                        // we do not continue examining this subtree of the search tree
                        //printf("parallel NOT continuing!");
                        cur--;
                        continue;
                    }
                }
                
                // put an "unassigned" color on the new cur
                if (cur<num_colors)  // for vertex cur (which is 0-indexed), only use colors 1..cur+1.  So the unassigned color is cur+2.
                    c[cur]=cur+2;
                else
                    c[cur]=num_colors+1;
            }
        }  // advancing to next vertex
        
    }  // main while loop
    
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
