import pandas as pd
import matplotlib.pyplot as plt

# Load the CSV data
data = pd.read_csv('results.csv')

# Create a figure with two subplots (side by side)
fig, axes = plt.subplots(1, 2, figsize=(14, 6), sharey=True)  # Share y-axis for both plots

# Plot for the 'gossip' algorithm
ax = axes[0]
for topo in data['topology'].unique():
    subset = data[(data['algorithm'] == 'gossip') & (data['topology'] == topo)]
    ax.plot(subset['size'], subset['average_time'], marker='o', label=f'{topo} topology')

ax.set_title('Gossip Algorithm Performance')
ax.set_xlabel('Number of Nodes')
ax.set_ylabel('Average Time (ms) [log scale]')
ax.set_yscale('log')
ax.grid(True, which="both", ls="--")
ax.legend()

# Plot for the 'push-sum' algorithm
ax = axes[1]
for topo in data['topology'].unique():
    subset = data[(data['algorithm'] == 'push-sum') & (data['topology'] == topo)]
    ax.plot(subset['size'], subset['average_time'], marker='o', label=f'{topo} topology')

ax.set_title('Push-Sum Algorithm Performance')
ax.set_xlabel('Number of Nodes')
ax.grid(True, which="both", ls="--")
ax.legend()

# Adjust the layout and show the combined plot
plt.tight_layout()
plt.savefig('gossip_pushsum_performance.png')
plt.show()
