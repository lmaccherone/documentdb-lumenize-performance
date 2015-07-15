# documentdb-lumenize performance testing

The code in this repository will perform a moderately complicated aggregation operation (a 2D pivot table) on relatively simple documents. It will do the aggregation in two ways:

1. Inside of DocumentDB using documentdb-lumenize (move the code to the data)
2. Inside of node.js by pulling all the data down (move the data to the code)

I used the createVariedData script in documentdb-mock and created 10,000 documents. Then I ran the code in this repository from my laptop over a 20Mb connection as well as on an Azure Websites within the same data center (East US) as my DocumentDB instance. 

I used an S3 (hightest level) DocumentDB instance with 2500 RUs per second available.

**The results are very satisfying!**


## Summary

* Aggregations of 10,000 documents in 1.3-1.5 seconds.
* 5x-7x reduction in latency for remote execution over a 20Mb connection
* 2.7x-3.9x reduction in latency when executed in the same data center (US East)
* 320x reduction in bytes transfered (lower bandwidth requirements)
* 25-27% more consumption of request units (RUs)


## Other observations

* It mattered little what size Azure Websites instance I used (not to be confused with DocumentDB tier which was S3 for all experiments). I tried B1, S1, and S3 with S3 being no more than a few percentage points faster than B1. I suspect this might matter more under load.

* Latency vs throughput 
  
  * Throughput is limited by the available RUs. If every aggregation was 10,000 documents, you could still do over 40 of them per minute. You'd need thousands of users looking to get reports every few minutes to swamp that. I suspect a typical load would be much less than 10,000 documents especially considering that Lumenize is designed to be incrementally updated. My initial assumption was that I would run out of RUs long before I ran out of the 10GB storage space allocated to each DocumentDB colleciton (think "partition" or "shard"). Now, I suspect the opposite is true and I'll hit the 10GB limit first. Throughput-wise, I could use S2 or even S1 tier DocumentDB for the throughput I anticipate at first.

  * That said, I may stick with the S3 tier for latency reasons. I can spend an S3's allocation for a single second with a single aggregation. If I only had 1/2.5 as much RUs, I'd have to spread the aggregation out over 2.5 times as much time and my latency would increase by 2.5x. $100/month is very reasonable to support thousands of aggregation requests. On the other hand, if the vast majority of real world aggregations can be done in an S2 or even S1, then I may bump down to that.

* Using S3s, this system has over an order of magnitude lower latency than a similar MongoDB-based solution I previously helped implement. That system required ~15 seconds for 10,000-document aggregations. Roughly half of that time was spent on data transfer but even so, this DocumentDB solution is still 5x-6x faster than if we could have run our MongoDB aggregations in the same data center and had zero data transfer time.


## Detail measurements

* Remote on my 20Mb connection

  * faster: 5.95x, 6.59x, 5.32x
  
  * more_costly: 1.24x, 1.27x, 1.28x

* Running in the same data center using S1 Website S3 DocumentDB

  * faster: 2.71x, 3.63x, 3.72x
  
  * more_costly: 1.27x, 1.25x, 1.27x

* Running in the same data center using S3 Website S3 DocumentDB

  * faster: 2.74x, 3.15x, 2.20x
  
  * (Since RUs varied so little in the earlier experiments, I stopped recording it.)

* Running in the same data center using B1 Website S3 DocumentDB

  * faster: 3.31x, 3.93x, 3.15x


## Slightly (25-27%) more RUs consumed

The only penalty for using documentdb-lumenize to do your aggregations inside of DocumentDB over aggregating outside of the DocumentDB is that it consumes more request units (RUs) to do so. I ran it dozens of times and it consistently used 25-27% more RUs. In theory, this means that you might hit your resource limits sooner for a particular collection (think "shard" or "partition"), potentially costing you a bit more for the database part of your bill. However, it should reduce the app server portion of your bill and will significantly reduce (300x) any bandwidth costs that you pay for.