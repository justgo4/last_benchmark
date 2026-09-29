import sys, bench
sizes={"integer50":200000000,"json_escape":16000000,"merge_sort":1000000,"binary_search":1000000,"prefix_sum":8000000,"matrix_mul":320,"bfs":200000,"dijkstra":100000,"union_find":1000000,"mandelbrot":1600,"dynamic_array":5000000,"linked_list":4000000,"queue_ring":10000000,"hash_table":1000000,"binary_heap":1000000,"bst":300000,"trie":100000}
k=sys.argv[1]
bench.bench(k, int(sys.argv[2]) if len(sys.argv)>2 else sizes[k])
