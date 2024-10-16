// util/utilities.q - Utilities library
// Copyright (c) 2021 Kx Systems Inc
//
// Includes range, arange, combs, eye, iMax, iMin,
// linearSpace, shape, trainTestSplit, tab2df,
// df2tabTimezone, df2tab

\d .ml

// @kind function
// @category utilities
// @desc Range of values
// @param array {number[]} A numerical array 
// @returns {float} Range of its values
range:{[array]
  max[array]-min array
  }

// @kind function
// @category utilities
// @desc Evenly-spaced values
// @param start {number} Start of the interval (inclusive)
// @param end {number} End of the interval (non-inclusive)
// @param step {number} Spacing between values 
// @return {number[]} A vector of evenly-spaced values between start and end
//   in steps of length `step`
arange:{[start;end;step]
  start+step*til 0|ceiling(end-start)%step
  }

// @kind function
// @category utilities
// @desc Unique combinations of a vector or matrix
// @param n {int} Number of values required for combinations
// @param degree {int} Degree of the combinations to be produced
// @return {int[]} Unique combinations of values from the data 
combs:{[n;degree]
  flip(degree-1)i.combFunc[n]/enlist til n
  }

// @kind function
// @category utilities
// @desc Create identity matrix 
// @param n {int} Width/height of identity matrix
// @return {int[]} Identity matrix of height/width n
eye:{[n]
  @[n#0.;;:;1.]each til n
  }

// @kind function
// @category utilities
// @desc Index of the first occurance of the maximum value in a list
// @param array {number[]} Array of values 
// @return {number} The index of the maximum element of the array
iMax:{[array]
  array?max array
  }

// @kind function
// @category utilities
// @desc Index of minimum element of a list
// @param array {number[]} Array of values 
// @return {number} The index of the minimum element of the array
iMin:{[array]
  array?min array
  }

// @kind function
// @category utilities
// @desc Create an array of evenly-spaced values
// @param start {number} Start of the interval (inclusive)
// @param end {number} End of the interval (non-inclusive)
// @param n {int} How many spaces are to be created
// @return {number[]} A vector of `n` evenly-spaced values between
//   start and end
linearSpace:{[start;end;n]
  start+til[n]*(end-start)%n-1
  }

// @kind function
// @category utilities
// @desc Shape of a matrix
// @param matrix {number[]} Matrix of values
// @return {number[]} Its shape as a list of dimensions
shape:{[matrix]
  -1_count each first scan matrix
  }

// @kind function
// @category utilities
// @desc Split data into training and test sets
// @param data {any[]} Matrix of input values
// @param target {any[]} A vector of target values the same count as data
// @param size {float[]} Percentage size of the testing set
// @return {dictionary} Contains the data matrix and target split into a
//   training and testing set
trainTestSplit:{[data;target;size]
  dictKeys:`xtrain`ytrain`xtest`ytest;
  n:count data;
  split:(0,floor n*1-size)_neg[n]?n;
  dictVals:raze(data;target)@\:/:split;
  dictKeys!dictVals
  }

// @kind function
// @category utilities
// @desc Convert q table to Pandas dataframe
// @param tab {table} A q table
// @return {<} a Pandas dataframe
tab2df:{
  if[.pykx.loaded;:.pykx.eval["lambda x:x"].pykx.topd x];
  keyTab:keys x;
  c:cols x:0!x;
  c1:i.findCols[x;"bxhijef"];
  df:i.pandasDF[{$[count y;y!x y;()!()]}[x;c1]];
  cls:c except c1;
  // Early exit if only numeric columns existed
  if[0=count cls;:df];
  updTab:@[flip x;i.findCols[x;"c"];enlist each];
  // Convert temporal columns to timestamps and
  // assign as datetime64[ns] columns
  timeCols:i.findCols[x;"pmdznuvt"];
  timeTab:?[updTab;();0b;timeCols!timeCols];
  timeTab:@[timeTab;timeCols;{("p"$@[4#+["d"$0];-16+type x]x)-"p"$1970.01m}];
  convfn:{x[`:assign][z pykw i.npArray[y z;"datetime64[ns]"]]};
  df:convfn/[df;count[timeCols]#enlist timeTab;timeCols];
  // Convert symbols to strings (char vector conversions are faster)
  // otherwise assign the underlying datatype
  convfn:{x[=;z;enlist $[11h=type dat:y z;string dat;dat]]}[df;updTab];
  convfn each cls except timeCols;
  // Reorder the columns based on initial input
  df:df[`:reindex][`columns pykw c];
  // Index the table if originally keyed
  $[count keyTab;
    df[`:set_index]keyTab;
    df
    ]
 }

// @kind function
// @category utilities
// @desc Convert a pandas dataframe containing datetime timezones and
//   datetime objects (datetime.datetime, datetime.time) to a q table
// @param tab {<} An embedPy representation of a Pandas dataframe
// @param local {boolean} Indicates if timezone objects are to be converted
//   to local time (1b) or UTC (0b)
// @param qObj {boolean} Indicates if python datetime.date/datetime.time
//   objects are returned as q (1b) or foreign objects (0b)
// @return {<} a q table
df2tabTimezone:{[tab;local;qObj]
  index:$[enlist[::]~tab[`:index.names]`;0;tab[`:index.nlevels]`];
  tab:$[index;tab[`:reset_index][];tab];
  numpyCols:csym tab[`:columns.to_numpy][]`;
  if[`index in numpyCols;numpyCols:numpyCols except`index;index-:1];
  dataArgs:enlist[`exclude]!enlist`float32`datetime`datetimetz`timedelta;
  dict:tab[`:select_dtypes][pykwargs dataArgs][`:to_dict;`list]`;
  dateTimeData:tab[`:select_dtypes][`include pykw`datetime];
  dict,:i.dateConvert dateTimeData;
  timeDeltaData:tab[`:select_dtypes][`include pykw`timedelta];
  dict,:i.dateDict[timeDeltaData]+"n"$0;
  timezoneData:tab[`:select_dtypes][`include pykw`datetimetz];
  dict,:i.timezoneConvert[timezoneData;local];
  float32Data:tab[`:select_dtypes][`include pykw`float32][`:to_dict;`list]`;
  dict,:i.float32Convert[float32Data;local];
  // Check if the first value in columns are foreign
  foreign:where 112h=type each first each value dict;
  if[0<count foreign;
    dictKeys:key[dict]foreign;
    dictVals:i.dateTimeConvert[;qObj] each dict dictKeys;
    dict,:dictKeys!dictVals
    ];
  tbl:flip numpyCols#dict;
  / convert syms to strings (to match embedpy behaviour)
  index!@[tbl;exec c from meta tbl where t="s";string]
  }

// @kind function
// @category utilities
// @desc Convert pandas dataframe to q table
// @param tab {<} An embedPy representation of a Pandas dataframe
// @return {<} a q table
df2tab:df2tabTimezone[;0b;0b]
