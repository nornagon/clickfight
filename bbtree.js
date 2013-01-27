/* Copyright (c) 2009 Scott Lembcke
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
// Modified for use without chipmunk


/**
  Here's some useful stuff you can do:

  // The number of objects in the spatial index.
  count = 0;

  // Iterate the objects in the spatial index. @c func will be called once for each object.
  each(func);
  
  // Returns true if the spatial index contains the given object.
  // Most spatial indexes use hashed storage, so you must provide a hash value too.
  contains(obj, hashid);

  // Add an object to a spatial index.
  insert(obj, hashid);

  // Remove an object from a spatial index.
  remove(obj, hashid);
  
  // Perform a full reindex of a spatial index.
  reindex();

  // Reindex a single object in the spatial index.
  reindexObject(obj, hashid);

  // Perform a point query against the spatial index, calling @c func for each potential match.
  // A pointer to the point will be passed as @c obj1 of @c func.
  // func(shape);
  pointQuery(point, func);

  // Perform a segment query against the spatial index, calling @c func for each potential match.
  // func(shape);
  segmentQuery(vect a, vect b, t_exit, func);

  // Perform a rectangle query against the spatial index, calling @c func for each potential match.
  // func(shape);
  query(bb, func);

  // Simultaneously reindex and find all colliding objects.
  // @c func will be called once for each potentially overlapping pair of objects found.
  // If the spatial index was initialized with a static index, it will collide it's objects against that as well.
  reindexQuery(callback(obj1, obj2));
*/


// This file implements a modified AABB tree for collision detection.

if (typeof(window) === 'object') {
  exports = window;
} else {
  var max = Math.max;
  var min = Math.min;
}

// Bounding box.
var BB = exports.BB = function(l, b, r, t) {
  this.l = l;
  this.b = b;
  this.r = r;
  this.t = t;
};

// Helper so you don't need to use 'new' everywhere.
exports.bb = function(l, b, r, t) { return new BB(l, b, r, t); };


/*
 * Bounding box trees are designed to work in pairs - you make a static tree (for your
 * static objects) and a dynamic tree for dynamic objects.
 *
 * That way you don't have to check to see if your static objects are colliding with each
 * other.
 *
 * var static = new BBTree();
 * var dynamic = new BBTree(static);
 */
var BBTree = exports.BBTree = function(staticIndex)
{
  this.staticIndex = staticIndex;
   
  if(staticIndex){
    if (staticIndex.dynamicIndex) {
      throw new Error("This static index is already associated with a dynamic index.");
    }
    staticIndex.dynamicIndex = this;
  }
 
  // This is a hash from object ID -> object for the objects stored in the BBTree.
  this.leaves = {};
  // A count of the number of leaves in the BBTree.
  this.count = 0;

  this.root = null;
  
  // A linked list containing an object pool of tree nodes and pairs.
  this.pooledNodes = null;
  this.pooledPairs = null;
  
  this.stamp = 0;
};

var Node = function(tree, a, b)
{
  this.obj = null;
  this.bb_l = min(a.bb_l, b.bb_l);
  this.bb_b = min(a.bb_b, b.bb_b);
  this.bb_r = max(a.bb_r, b.bb_r);
  this.bb_t = max(a.bb_t, b.bb_t);
  this.parent = null;
  
  this.setA(a);
  this.setB(b);
};

BBTree.prototype.makeNode = function(a, b)
{
  var node = this.pooledNodes;
  if(node){
    this.pooledNodes = node.parent;
    node.constructor(this, a, b);
    return node;
  } else {
    return new Node(this, a, b);
  }
};

var numLeaves = 0;
var Leaf = function(tree, obj)
{
  this.obj = obj;
  tree.getBB(obj, this);

  this.parent = null;

  this.stamp = 1;
  this.pairs = null;
};

// **** Misc Functions

BBTree.prototype.getBB = function(obj, dest)
{
  dest.bb_l = obj.bb_l;
  dest.bb_b = obj.bb_b;
  dest.bb_r = obj.bb_r;
  dest.bb_t = obj.bb_t;
};

BBTree.prototype.getStamp = function()
{
  var dynamic = this.dynamicIndex;
  return (dynamic && dynamic.stamp ? dynamic.stamp : this.stamp);
};

BBTree.prototype.incrementStamp = function()
{
  if(this.dynamicIndex && this.dynamicIndex.stamp){
    this.dynamicIndex.stamp++;
  } else {
    this.stamp++;
  }
}

// **** Pair/Thread Functions

var numPairs = 0;
// Objects created with constructors are faster than object literals. :(
var Pair = function(leafA, nextA, leafB, nextB)
{
  this.prevA = null;
  this.leafA = leafA;
  this.nextA = nextA;

  this.prevB = null;
  this.leafB = leafB;
  this.nextB = nextB;
};

BBTree.prototype.makePair = function(leafA, nextA, leafB, nextB)
{
  //return new Pair(leafA, nextA, leafB, nextB);
  var pair = this.pooledPairs;
  if (pair)
  {
    this.pooledPairs = pair.prevA;

    pair.prevA = null;
    pair.leafA = leafA;
    pair.nextA = nextA;

    pair.prevB = null;
    pair.leafB = leafB;
    pair.nextB = nextB;

    //pair.constructor(leafA, nextA, leafB, nextB);
    return pair;
  } else {
    numPairs++;
    return new Pair(leafA, nextA, leafB, nextB);
  }
};

Pair.prototype.recycle = function(tree)
{
  this.prevA = tree.pooledPairs;
  tree.pooledPairs = this;
};

var unlinkThread = function(prev, leaf, next)
{
  if(next){
    if(next.leafA === leaf) next.prevA = prev; else next.prevB = prev;
  }
  
  if(prev){
    if(prev.leafA === leaf) prev.nextA = next; else prev.nextB = next;
  } else {
    leaf.pairs = next;
  }
};

Leaf.prototype.clearPairs = function(tree)
{
  var pair = this.pairs,
    next;

  this.pairs = null;
  
  while(pair){
    if(pair.leafA === this){
      next = pair.nextA;
      unlinkThread(pair.prevB, pair.leafB, pair.nextB);
    } else {
      next = pair.nextB;
      unlinkThread(pair.prevA, pair.leafA, pair.nextA);
    }
    pair.recycle(tree);
    pair = next;
  }
};

var pairInsert = function(a, b, tree)
{
  var nextA = a.pairs, nextB = b.pairs;
  var pair = tree.makePair(a, nextA, b, nextB);
  a.pairs = b.pairs = pair;

  if(nextA){
    if(nextA.leafA === a) nextA.prevA = pair; else nextA.prevB = pair;
  }
  
  if(nextB){
    if(nextB.leafA === b) nextB.prevA = pair; else nextB.prevB = pair;
  }
};

// **** Node Functions

Node.prototype.recycle = function(tree)
{
  this.parent = tree.pooledNodes;
  tree.pooledNodes = this;
};

Leaf.prototype.recycle = function(tree)
{
  // Its not worth the overhead to recycle leaves.
};

Node.prototype.setA = function(value)
{
  this.A = value;
  value.parent = this;
};

Node.prototype.setB = function(value)
{
  this.B = value;
  value.parent = this;
};

Leaf.prototype.isLeaf = true;
Node.prototype.isLeaf = false;

Node.prototype.otherChild = function(child)
{
  return (this.A == child ? this.B : this.A);
};

Node.prototype.replaceChild = function(child, value, tree)
{
  if(child != this.A && child != this.B) {
    console.error("Node is not a child of parent.");
  }
  
  if(this.A == child){
    this.A.recycle(tree);
    this.setA(value);
  } else {
    this.B.recycle(tree);
    this.setB(value);
  }
  
  for(var node=this; node; node = node.parent){
    //node.bb = bbMerge(node.A.bb, node.B.bb);
    var a = node.A;
    var b = node.B;
    node.bb_l = min(a.bb_l, b.bb_l);
    node.bb_b = min(a.bb_b, b.bb_b);
    node.bb_r = max(a.bb_r, b.bb_r);
    node.bb_t = max(a.bb_t, b.bb_t);
  }
};

Node.prototype.bbArea = Leaf.prototype.bbArea = function()
{
  return (this.bb_r - this.bb_l)*(this.bb_t - this.bb_b);
};

var bbTreeMergedArea = function(a, b)
{
  return (max(a.bb_r, b.bb_r) - min(a.bb_l, b.bb_l))*(max(a.bb_t, b.bb_t) - min(a.bb_b, b.bb_b));
};

// Collide the objects in an index against the objects in a staticIndex using the query callback function.
BBTree.prototype.collideStatic = function(staticIndex, func)
{
  if(staticIndex.count > 0){
    var query = staticIndex.query;

    this.each(function(obj) {
      query(obj, new BB(obj.bb_l, obj.bb_b, obj.bb_r, obj.bb_t), func);
    });
  }
};

// **** Subtree Functions

// Would it be better to make these functions instance methods on Node and Leaf?

var bbProximity = function(a, b)
{
  return Math.abs(a.bb_l + a.bb_r - b.bb_l - b.bb_r) + Math.abs(a.bb_b + b.bb_t - b.bb_b - b.bb_t);
};

var subtreeInsert = function(subtree, leaf, tree)
{
//  var s = new Error().stack;
//  traces[s] = traces[s] ? traces[s]+1 : 1;

  if(subtree == null){
    return leaf;
  } else if(subtree.isLeaf){
    return tree.makeNode(leaf, subtree);
  } else {
    var cost_a = subtree.B.bbArea() + bbTreeMergedArea(subtree.A, leaf);
    var cost_b = subtree.A.bbArea() + bbTreeMergedArea(subtree.B, leaf);
    
    if(cost_a === cost_b){
      cost_a = bbProximity(subtree.A, leaf);
      cost_b = bbProximity(subtree.B, leaf);
    }  

    if(cost_b < cost_a){
      subtree.setB(subtreeInsert(subtree.B, leaf, tree));
    } else {
      subtree.setA(subtreeInsert(subtree.A, leaf, tree));
    }
    
//    subtree.bb = bbMerge(subtree.bb, leaf.bb);
    subtree.bb_l = min(subtree.bb_l, leaf.bb_l);
    subtree.bb_b = min(subtree.bb_b, leaf.bb_b);
    subtree.bb_r = max(subtree.bb_r, leaf.bb_r);
    subtree.bb_t = max(subtree.bb_t, leaf.bb_t);

    return subtree;
  }
};

Node.prototype.intersectsBB = Leaf.prototype.intersectsBB = function(bb)
{
  return (this.bb_l <= bb.r && bb.l <= this.bb_r && this.bb_b <= bb.t && bb.b <= this.bb_t);
};

var subtreeQuery = function(subtree, bb, func)
{
  //if(bbIntersectsBB(subtree.bb, bb)){
  if(subtree.intersectsBB(bb)){
    if(subtree.isLeaf){
      func(subtree.obj);
    } else {
      subtreeQuery(subtree.A, bb, func);
      subtreeQuery(subtree.B, bb, func);
    }
  }
};

/// Returns the fraction along the segment query the node hits. Returns Infinity if it doesn't hit.
var nodeSegmentQuery = function(node, a, b)
{
  var idx = 1/(b.x - a.x);
  var tx1 = (node.bb_l == a.x ? -Infinity : (node.bb_l - a.x)*idx);
  var tx2 = (node.bb_r == a.x ?  Infinity : (node.bb_r - a.x)*idx);
  var txmin = min(tx1, tx2);
  var txmax = max(tx1, tx2);
  
  var idy = 1/(b.y - a.y);
  var ty1 = (node.bb_b == a.y ? -Infinity : (node.bb_b - a.y)*idy);
  var ty2 = (node.bb_t == a.y ?  Infinity : (node.bb_t - a.y)*idy);
  var tymin = min(ty1, ty2);
  var tymax = max(ty1, ty2);
  
  if(tymin <= txmax && txmin <= tymax){
    var min_ = max(txmin, tymin);
    var max_ = min(txmax, tymax);
    
    if(0.0 <= max_ && min_ <= 1.0) return max(min_, 0.0);
  }
  
  return Infinity;
};

var subtreeSegmentQuery = function(subtree, a, b, t_exit, func)
{
  if(subtree.isLeaf){
    return func(subtree.obj);
  } else {
    var t_a = nodeSegmentQuery(subtree.A, a, b);
    var t_b = nodeSegmentQuery(subtree.B, a, b);
    
    if(t_a < t_b){
      if(t_a < t_exit) t_exit = min(t_exit, subtreeSegmentQuery(subtree.A, a, b, t_exit, func));
      if(t_b < t_exit) t_exit = min(t_exit, subtreeSegmentQuery(subtree.B, a, b, t_exit, func));
    } else {
      if(t_b < t_exit) t_exit = min(t_exit, subtreeSegmentQuery(subtree.B, a, b, t_exit, func));
      if(t_a < t_exit) t_exit = min(t_exit, subtreeSegmentQuery(subtree.A, a, b, t_exit, func));
    }
    
    return t_exit;
  }
};

BBTree.prototype.subtreeRecycle = function(node)
{
  if(node.isLeaf){
    this.subtreeRecycle(node.A);
    this.subtreeRecycle(node.B);
    node.recycle(this);
  }
};

var subtreeRemove = function(subtree, leaf, tree)
{
  if(leaf == subtree){
    return null;
  } else {
    var parent = leaf.parent;
    if(parent == subtree){
      var other = subtree.otherChild(leaf);
      other.parent = subtree.parent;
      subtree.recycle(tree);
      return other;
    } else {
      parent.parent.replaceChild(parent, parent.otherChild(leaf), tree);
      return subtree;
    }
  }
};

// **** Marking Functions

/*
typedef struct MarkContext {
  bbTree *tree;
  Node *staticRoot;
  cpSpatialIndexQueryFunc func;
} MarkContext;
*/

var bbTreeIntersectsNode = function(a, b)
{
  return (a.bb_l <= b.bb_r && b.bb_l <= a.bb_r && a.bb_b <= b.bb_t && b.bb_b <= a.bb_t);
};

var markLeafQuery = function(subtree, leaf, left, tree, func)
{
  if(bbTreeIntersectsNode(leaf, subtree)){
    if(subtree.isLeaf){
      if(left){
        pairInsert(leaf, subtree, tree);
      } else {
        if(subtree.stamp < leaf.stamp) pairInsert(subtree, leaf, tree);
        if(func) func(leaf.obj, subtree.obj);
      }
    } else {
      markLeafQuery(subtree.A, leaf, left, tree, func);
      markLeafQuery(subtree.B, leaf, left, tree, func);
    }
  }
};

var markLeaf = function(leaf, tree, staticRoot, func)
{
  if(leaf.stamp == tree.getStamp()){
    if(staticRoot) markLeafQuery(staticRoot, leaf, false, tree, func);
    
    for(var node = leaf; node.parent; node = node.parent){
      if(node == node.parent.A){
        markLeafQuery(node.parent.B, leaf, true, tree, func);
      } else {
        markLeafQuery(node.parent.A, leaf, false, tree, func);
      }
    }
  } else {
    var pair = leaf.pairs;
    while(pair){
      if(leaf === pair.leafB){
        if(func) func(pair.leafA.obj, leaf.obj);
        pair = pair.nextB;
      } else {
        pair = pair.nextA;
      }
    }
  }
};

var markSubtree = function(subtree, tree, staticRoot, func)
{
  if(subtree.isLeaf){
    markLeaf(subtree, tree, staticRoot, func);
  } else {
    markSubtree(subtree.A, tree, staticRoot, func);
    markSubtree(subtree.B, tree, staticRoot, func);
  }
};

// **** Leaf Functions

Leaf.prototype.containsObj = function(obj)
{
  return (this.bb_l <= obj.bb_l && this.bb_r >= obj.bb_r && this.bb_b <= obj.bb_b && this.bb_t >= obj.bb_t);
};

Leaf.prototype.update = function(tree)
{
  var root = tree.root;
  var obj = this.obj;

  //if(!bbContainsBB(this.bb, bb)){
  if(!this.containsObj(obj)){
    tree.getBB(this.obj, this);
    
    root = subtreeRemove(root, this, tree);
    tree.root = subtreeInsert(root, this, tree);
    
    this.clearPairs(tree);
    this.stamp = tree.getStamp();
    
    return true;
  }
  
  return false;
};

Leaf.prototype.addPairs = function(tree)
{
  var dynamicIndex = tree.dynamicIndex;
  if(dynamicIndex){
    var dynamicRoot = dynamicIndex.root;
    if(dynamicRoot){
      markLeafQuery(dynamicRoot, this, true, dynamicIndex, null);
    }
  } else {
    var staticRoot = tree.staticIndex.root;
    markLeaf(this, tree, staticRoot, null);
  }
};

// **** Insert/Remove

var nextObjId = 1000;
BBTree.prototype.insert = function(obj)
{
  var leaf = new Leaf(this, obj);

  if (!obj._id) {
    obj._id = nextObjId++;
  }

  this.leaves[obj._id] = leaf;
  this.root = subtreeInsert(this.root, leaf, this);
  this.count++;
  
  leaf.stamp = this.getStamp();
  leaf.addPairs(this);
  this.incrementStamp();
};

BBTree.prototype.remove = function(obj)
{
  var leaf = this.leaves[obj._id];

  if (!leaf) return;

  delete this.leaves[obj._id];
  this.root = subtreeRemove(this.root, leaf, this);
  this.count--;

  leaf.clearPairs(this);
  leaf.recycle(this);
};

BBTree.prototype.contains = function(obj)
{
  return this.leaves[obj._id] !== null;
};

// **** Reindex
var voidQueryFunc = function(obj1, obj2){};

BBTree.prototype.reindexQuery = function(func)
{
  if(!this.root) return;
  
  // LeafUpdate() may modify this.root. Don't cache it.
  var hashid,
    leaves = this.leaves;
  for (hashid in leaves)
  {
    leaves[hashid].update(this);
  }
  
  var staticIndex = this.staticIndex;
  var staticRoot = staticIndex && staticIndex.root;
  
  markSubtree(this.root, this, staticRoot, func);
  if(staticIndex && !staticRoot) this.collideStatic(this, staticIndex, func);
  
  this.incrementStamp();
};

BBTree.prototype.reindex = function()
{
  this.reindexQuery(voidQueryFunc);
};

BBTree.prototype.reindexObject = function(obj)
{
  var leaf = this.leaves[obj._id];
  if(leaf){
    if(leaf.update(this)) leaf.addPairs(this);
    this.incrementStamp();
  }
};

// **** Query

BBTree.prototype.pointQuery = function(point, func)
{
  // The base collision object is the provided point.
  if(this.root) subtreeQuery(this.root, new BB(point.x, point.y, point.x, point.y), func);
};

BBTree.prototype.segmentQuery = function(a, b, t_exit, func)
{
  if(this.root) subtreeSegmentQuery(this.root, a, b, t_exit, func);
};

BBTree.prototype.query = function(bb, func)
{
  if(this.root) subtreeQuery(this.root, bb, func);
};

// **** Misc

BBTree.prototype.count = function()
{
  return this.count;
};

BBTree.prototype.each = function(func)
{
  var hashid;
  for(hashid in this.leaves)
  {
    func(this.leaves[hashid].obj);
  }
};

// **** Tree Optimization

var bbTreeMergedArea2 = function(node, l, b, r, t)
{
  return (max(node.bb_r, r) - min(node.bb_l, l))*(max(node.bb_t, t) - min(node.bb_b, b));
};

var partitionNodes = function(tree, nodes, offset, count)
{
  if(count == 1){
    return nodes[offset];
  } else if(count == 2) {
    return tree.makeNode(nodes[offset], nodes[offset + 1]);
  }
  
  // Find the AABB for these nodes
  //var bb = nodes[offset].bb;
  var node = nodes[offset];
  var bb_l = node.bb_l,
    bb_b = node.bb_b,
    bb_r = node.bb_r,
    bb_t = node.bb_t;

  var end = offset + count;
  for(var i=offset + 1; i<end; i++){
    //bb = bbMerge(bb, nodes[i].bb);
    node = nodes[i];
    bb_l = min(bb_l, node.bb_l);
    bb_b = min(bb_b, node.bb_b);
    bb_r = max(bb_r, node.bb_r);
    bb_t = max(bb_t, node.bb_t);
  }
  
  // Split it on it's longest axis
  var splitWidth = (bb_r - bb_l > bb_t - bb_b);
  
  // Sort the bounds and use the median as the splitting point
  var bounds = new Array(count*2);
  if(splitWidth){
    for(var i=offset; i<end; i++){
      bounds[2*i + 0] = nodes[i].bb_l;
      bounds[2*i + 1] = nodes[i].bb_r;
    }
  } else {
    for(var i=offset; i<end; i++){
      bounds[2*i + 0] = nodes[i].bb_b;
      bounds[2*i + 1] = nodes[i].bb_t;
    }
  }
  
  bounds.sort(function(a, b) {
    // This might run faster if the function was moved out into the global scope.
    return a - b;
  });
  var split = (bounds[count - 1] + bounds[count])*0.5; // use the median as the split

  // Generate the child BBs
  //var a = bb, b = bb;
  var a_l = bb_l, a_b = bb_b, a_r = bb_r, a_t = bb_t;
  var b_l = bb_l, b_b = bb_b, b_r = bb_r, b_t = bb_t;

  if(splitWidth) a_r = b_l = split; else a_t = b_b = split;
  
  // Partition the nodes
  var right = end;
  for(var left=offset; left < right;){
    var node = nodes[left];
//  if(bbMergedArea(node.bb, b) < bbMergedArea(node.bb, a)){
    if(bbTreeMergedArea2(node, b_l, b_b, b_r, b_t) < bbTreeMergedArea2(node, a_l, a_b, a_r, a_t)){
      right--;
      nodes[left] = nodes[right];
      nodes[right] = node;
    } else {
      left++;
    }
  }
  
  if(right == count){
    var node = null;
    for(var i=offset; i<end; i++) node = subtreeInsert(node, nodes[i], tree);
    return node;
  }
  
  // Recurse and build the node!
  return NodeNew(tree,
    partitionNodes(tree, nodes, offset, right - offset),
    partitionNodes(tree, nodes, right, end - right)
  );
};

//static void
//bbTreeOptimizeIncremental(bbTree *tree, int passes)
//{
//  for(int i=0; i<passes; i++){
//    Node *root = tree.root;
//    Node *node = root;
//    int bit = 0;
//    unsigned int path = tree.opath;
//    
//    while(!NodeIsLeaf(node)){
//      node = (path&(1<<bit) ? node.a : node.b);
//      bit = (bit + 1)&(sizeof(unsigned int)*8 - 1);
//    }
//    
//    root = subtreeRemove(root, node, tree);
//    tree.root = subtreeInsert(root, node, tree);
//  }
//}

BBTree.prototype.optimize = function()
{
  var nodes = new Array(this.count);
  var i = 0;

  for (var hashid in this.leaves)
  {
    nodes[i++] = this.nodes[hashid];
  }
  
  tree.subtreeRecycle(root);
  this.root = partitionNodes(tree, nodes, nodes.length);
};

// **** Debug Draw

var nodeRender = function(node, depth)
{
  if(!node.isLeaf && depth <= 10){
    nodeRender(node.a, depth + 1);
    nodeRender(node.b, depth + 1);
  }
  
//  var bb = node.bb;
  
  var str = '';
  for(var i = 0; i < depth; i++) {
    str += ' ';
  }

//  console.log(str + bb.b + ' ' + bb.t);
};

BBTree.prototype.log = function(){
  if(this.root) nodeRender(this.root, 0);
};

