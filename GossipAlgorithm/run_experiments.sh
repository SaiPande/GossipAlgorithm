#!/bin/bash

# Define algorithms, topologies, and node sizes
ALGORITHMS=("gossip" "push-sum")
TOPOLOGIES=("full" "line" "3D" "imp3D")
SIZES=(500 1000 1500 2000 2500 3000 3500 4000 4500 5000 5500 6000 6500 7000 7500 8000 8500 9000 9500 10000)
RUNS=10  # Number of runs for each configuration

# Prepare the CSV header
echo "algorithm,topology,size,average_time" > results.csv

# Loop through each combination of algorithm, topology, and node size
for ALG in "${ALGORITHMS[@]}"; do
  for TOP in "${TOPOLOGIES[@]}"; do
    for SIZE in "${SIZES[@]}"; do
      echo "Running $ALG on $TOP topology with $SIZE nodes..."

      total_time=0  # Initialize total time to accumulate
      valid_runs=0  # Count valid runs for averaging

      # Run the simulation 5 times to compute the average time
      for ((i=1; i<=RUNS; i++)); do
        OUTPUT=$(./project2 $SIZE $TOP $ALG)  # Execute the command and capture the output

        # Extract the numerical convergence time using awk
        TIME=$(echo "$OUTPUT" | awk '/Convergence time:/ {print $3}')
        
        # Check if the time extraction was successful
        if [[ -n "$TIME" ]]; then
          total_time=$(echo "$total_time + $TIME" | bc)  # Accumulate the total time
          valid_runs=$((valid_runs + 1))
        #   echo "Run $i for $ALG on $TOP with $SIZE nodes: $TIME ms"
        else
          echo "Error parsing time for $ALG on $TOP with $SIZE nodes (Run $i). Skipping..."
        fi
      done

      # Check if any valid runs were performed
      if [[ "$valid_runs" -gt 0 ]]; then
        # Calculate the average time over the valid runs
        average_time=$(echo "scale=2; $total_time / $valid_runs" | bc)
        echo "$ALG,$TOP,$SIZE,$average_time" >> results.csv
        echo "Completed $ALG on $TOP with $SIZE nodes. Average time: $average_time ms"
      else
        echo "No valid runs for $ALG on $TOP with $SIZE nodes."
      fi
    done
  done
done