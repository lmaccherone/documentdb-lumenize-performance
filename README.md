# documentdb-lumenize performance testing

The code in this repository will run the same 

I used the generateVariedData script in documentdb-mock and created 10,000 documents. Then I ran the code in this repository both remotely and inside Azure Websites within the same data center (East US). 

**The results are very promising!**

Running in the same data center
faster: 2.71, 3.63, 3.72
more_costly: 1.27, 1.25, 1.27

Remote on my 20Mb connection
faster: 5.95, 6.59, 5.32
more_costly: 1.24, 1.27, 1.28
