
// C++ program to verify precoloring extension for star (vertex) chromatic number.

#include <vector>
#include <string>
#include <fstream>


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
    std::vector<cFourSetBlocker> FourSets;  // indexed by each vertex, gives the sets to check for the star chromatic condition on P4s and C4s.
    
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
                
            }
            else if (line.rfind("G=",0)==0)
            {
                
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
