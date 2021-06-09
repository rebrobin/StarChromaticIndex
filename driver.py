
# driver.py

from PrecoloringExtension import check_precoloring_extension
import sys
from sage.all import *

# Run with parallel_job_number>=parallel_num_jobs to find out how many nodes at parallel_depth.

if __name__=="__main__":
    if len(sys.argv)<=1:
        print("Pass the parallel_job_number on the command line.")
    else:
        parallel_job_number=int(sys.argv[1])
    
    print(f"driver.py running with parallel_job_number={parallel_job_number}")
    result=check_precoloring_extension(
        G=Graph('IxKOgGDA_'),
        num_precolored_verts=9,
        num_colors=6,
        precolor_verts=[4, 6, 3, 2, 5, 8, 7, 1, 0],
        recolor_verts=[],
        extend_verts=[9],
        parallel_job_number=parallel_job_number,
        parallel_num_jobs=1,
        parallel_depth=6,
        )
