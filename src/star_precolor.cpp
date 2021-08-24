
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
            printf("line: %s\n",line.c_str());
            
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
            }
        }
    
    // no need to close the file, since the destructor automatically does this when the object goes out of scope.
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
}
