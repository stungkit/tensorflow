// Run optimize-batch-matmul pass only and check the results.
// RUN: litert-opt %s -tfl-optimize-batch-matmul | FileCheck %s

// CHECK-LABEL: FuseTransposeFCRhsToBatchMatmul
func.func @FuseTransposeFCRhsToBatchMatmul(%arg0: tensor<16x1024xf32>, %arg1: tensor<1024x128xf32>, %arg2: none) -> tensor<16x128xf32> {
  %cst = arith.constant dense<[1, 0]> : tensor<2xi32>
  %0 = "tfl.transpose"(%arg1, %cst) : (tensor<1024x128xf32>, tensor<2xi32>) -> tensor<128x1024xf32>
  // CHECK: "tfl.batch_matmul"(%arg0, %arg1)
  %1 = "tfl.fully_connected"(%arg0, %0, %arg2) {asymmetric_quantize_inputs = false, fused_activation_function = "NONE", keep_num_dims = false, weights_format = "DEFAULT"} : (tensor<16x1024xf32>, tensor<128x1024xf32>, none) -> tensor<16x128xf32>
  func.return %1 : tensor<16x128xf32>
  // CHECK: return %0 : tensor<16x128xf32>
}

// CHECK-LABEL: FuseTransposeFCLhsToBatchMatmul
func.func @FuseTransposeFCLhsToBatchMatmul(%arg0: tensor<1024x4xf32>, %arg1: tensor<8x1024xf32>, %arg2: tensor<4x256xf32>) -> tensor<8x256xf32> {
  %cst_0 = arith.constant dense<[1, 0]> : tensor<2xi32>
  %cst_1 = "tfl.no_value"() {value} : () -> none
  %0 = "tfl.transpose"(%arg0, %cst_0) : (tensor<1024x4xf32>, tensor<2xi32>) -> tensor<4x1024xf32>
  // CHECK: %[[RES0:.*]] = "tfl.batch_matmul"(%arg1, %arg0) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<8x1024xf32>, tensor<1024x4xf32>) -> tensor<8x4xf32>
  %1 = "tfl.fully_connected"(%0, %arg1, %cst_1) {asymmetric_quantize_inputs = false, fused_activation_function = "NONE", keep_num_dims = false, weights_format = "DEFAULT"} : (tensor<4x1024xf32>, tensor<8x1024xf32>, none) -> tensor<4x8xf32>
  // CHECK: %[[RES1:.*]] = "tfl.batch_matmul"(%[[RES0]], %arg2) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<8x4xf32>, tensor<4x256xf32>) -> tensor<8x256xf32>
  %2 = "tfl.batch_matmul"(%1, %arg2) {adj_x = true, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x8xf32>, tensor<4x256xf32>) -> tensor<8x256xf32>
  func.return %2 : tensor<8x256xf32>
  // CHECK: return %[[RES1]] : tensor<8x256xf32>
}

// CHECK-LABEL: Batchmatmul2Fullyconnected
// CHECK-NOT: "tfl.batch_matmul"
func.func @Batchmatmul2Fullyconnected(%arg0: tensor<4x128x2xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<[[1.0], [2.0]]> : tensor<2x1xf32>
  %1 = "tfl.batch_matmul"(%arg0, %0) {adj_x = false, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<2x1xf32>) -> tensor<4x128x1xf32>
  func.return %1 : tensor<4x128x1xf32>
  // CHECK-NEXT: %[[CONST_WEIGHT:.*]] = arith.constant
  // CHECK-SAME: [1.000000e+00, 2.000000e+00]
  // CHECK-SAME: tensor<1x2xf32>
  // CHECK: %[[FC_RES:.*]] = "tfl.fully_connected"(%arg0, %[[CONST_WEIGHT]]
  // CHECK-SAME: <{fused_activation_function = "NONE", keep_num_dims = true, weights_format = "DEFAULT"}> : (tensor<4x128x2xf32>, tensor<1x2xf32>, none) -> tensor<4x128x1xf32>
  // CHECK-NEXT: return %[[FC_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedAdjy
// CHECK-NOT: "tfl.batch_matmul"
func.func @Batchmatmul2FullyconnectedAdjy(%arg0: tensor<4x128x2xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<[[1.0, 2.0]]> : tensor<1x2xf32>
  %1 = "tfl.batch_matmul"(%arg0, %0) {adj_x = false, adj_y = true, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<1x2xf32>) -> tensor<4x128x1xf32>
  func.return %1 : tensor<4x128x1xf32>
  // CHECK: %[[CONST_WEIGHT:.*]] = arith.constant
  // CHECK-SAME: [1.000000e+00, 2.000000e+00]
  // CHECK-SAME: tensor<1x2xf32>
  // CHECK: %[[FC_RES:.*]] = "tfl.fully_connected"(%arg0, %[[CONST_WEIGHT]]
  // CHECK-SAME: <{fused_activation_function = "NONE", keep_num_dims = true, weights_format = "DEFAULT"}> : (tensor<4x128x2xf32>, tensor<1x2xf32>, none) -> tensor<4x128x1xf32>
  // CHECK-NEXT: return %[[FC_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedAdjx
// CHECK-NOT: "tfl.batch_matmul"
func.func @Batchmatmul2FullyconnectedAdjx(%arg0: tensor<4x2x128xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<[[1.0], [2.0]]> : tensor<2x1xf32>
  %1 = "tfl.batch_matmul"(%arg0, %0) {adj_x = true, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x2x128xf32>, tensor<2x1xf32>) -> tensor<4x128x1xf32>
  func.return %1 : tensor<4x128x1xf32>

  // CHECK: %[[TRANSPOSED_X:.*]] = "tfl.transpose"
  // CHECK-SAME: (tensor<4x2x128xf32>, tensor<3xi32>) -> tensor<4x128x2xf32>
  // CHECK-NEXT: %[[FC_RES:.*]] = "tfl.fully_connected"(%[[TRANSPOSED_X]]
  // CHECK-SAME: <{fused_activation_function = "NONE", keep_num_dims = true, weights_format = "DEFAULT"}> : (tensor<4x128x2xf32>, tensor<1x2xf32>, none) -> tensor<4x128x1xf32>
  // CHECK-NEXT: return %[[FC_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedBatchedY
// BMM can be converted to FC only if we have constant weight with rank 2.
// CHECK-NOT: "tfl.fully_connected"
func.func @Batchmatmul2FullyconnectedBatchedY(%arg0: tensor<4x128x2xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<42.> : tensor<4x2x1xf32>
  %1 = "tfl.batch_matmul"(%arg0, %0) {adj_x = false, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<4x2x1xf32>) -> tensor<4x128x1xf32>
  func.return %1 : tensor<4x128x1xf32>

  // CHECK: %[[BMM_RES:.*]] = "tfl.batch_matmul"
  // CHECK-NEXT: return %[[BMM_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedTransposedY
func.func @Batchmatmul2FullyconnectedTransposedY(%arg0: tensor<4x128x2xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<[[1.0], [2.0]]> : tensor<2x1xf32>
  %1 = "tfl.batch_matmul"(%arg0, %0) {adj_x = false, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<2x1xf32>) -> tensor<4x128x1xf32>
  func.return %1 : tensor<4x128x1xf32>
  // CHECK: %[[CONST_WEIGHT:.*]] = arith.constant
  // CHECK-SAME: [1.000000e+00, 2.000000e+00]
  // CHECK-SAME: tensor<1x2xf32>
  // CHECK: %[[FC_RES:.*]] = "tfl.fully_connected"(%arg0, %[[CONST_WEIGHT]]
  // CHECK-SAME: <{fused_activation_function = "NONE", keep_num_dims = true, weights_format = "DEFAULT"}> : (tensor<4x128x2xf32>, tensor<1x2xf32>, none) -> tensor<4x128x1xf32>
  // CHECK-NEXT: return %[[FC_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedNonConstY
// BMM can be converted to FC only if we have constant weight with rank 2.
// CHECK-NOT: "tfl.fully_connected"
func.func @Batchmatmul2FullyconnectedNonConstY(%arg0: tensor<4x128x2xf32>, %arg1: tensor<2x1xf32>) -> (tensor<4x128x1xf32>) {
  %0 = "tfl.batch_matmul"(%arg0, %arg1) {adj_x = false, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<2x1xf32>) -> tensor<4x128x1xf32>
  func.return %0 : tensor<4x128x1xf32>

  // CHECK: %[[BMM_RES:.*]] = "tfl.batch_matmul"
  // CHECK-NEXT: return %[[BMM_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedQDQ
// CHECK-NOT: "tfl.batch_matmul"
func.func @Batchmatmul2FullyconnectedQDQ(%arg0: tensor<4x128x2xf32>, %arg1: tensor<2x1xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<[[1.0], [2.0]]> : tensor<2x1xf32>
  %1 = "tfl.quantize"(%0) {qtype = tensor<2x1x!quant.uniform<i8:f32, 0.024986599940879671:92>>} : (tensor<2x1xf32>) -> tensor<2x1x!quant.uniform<i8:f32, 0.024986599940879671:92>>
  %2 = "tfl.dequantize"(%1) : (tensor<2x1x!quant.uniform<i8:f32, 0.024986599940879671:92>>) -> tensor<2x1xf32>
  %3 = "tfl.batch_matmul"(%arg0, %2) {adj_x = false, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<2x1xf32>) -> tensor<4x128x1xf32>
  func.return %3 : tensor<4x128x1xf32>
  // CHECK: %[[TRANSPOSED_X:.*]] = "tfl.transpose"
  // CHECK-SAME: (tensor<2x1xf32>, tensor<2xi32>) -> tensor<1x2xf32>
  // CHECK: %[[FC_RES:.*]] = "tfl.fully_connected"(%arg0, %[[TRANSPOSED_X]]
  // CHECK-SAME: <{fused_activation_function = "NONE", keep_num_dims = true, weights_format = "DEFAULT"}> : (tensor<4x128x2xf32>, tensor<1x2xf32>, none) -> tensor<4x128x1xf32>
  // CHECK-NEXT: return %[[FC_RES]]
}

// CHECK-LABEL: Batchmatmul2FullyconnectedQDQReshape
// CHECK-NOT: "tfl.batch_matmul"
func.func @Batchmatmul2FullyconnectedQDQReshape(%arg0: tensor<4x128x2xf32>) -> (tensor<4x128x1xf32>) {
  %0 = arith.constant dense<[[1.0], [2.0]]> : tensor<2x1xf32>
  %1 = "tfl.quantize"(%0) {qtype = tensor<2x1x!quant.uniform<i8:f32, 0.024986599940879671:92>>} : (tensor<2x1xf32>) -> tensor<2x1x!quant.uniform<i8:f32, 0.024986599940879671:92>>
  %2 = "tfl.dequantize"(%1) : (tensor<2x1x!quant.uniform<i8:f32, 0.024986599940879671:92>>) -> tensor<2x1xf32>
  %cst_shape = arith.constant dense<[2, 1]> : tensor<2xi32>
  %3 = "tfl.reshape"(%2, %cst_shape) : (tensor<2x1xf32>, tensor<2xi32>) -> tensor<2x1xf32>
  %4 = "tfl.batch_matmul"(%arg0, %3) {adj_x = false, adj_y = false, asymmetric_quantize_inputs = false} : (tensor<4x128x2xf32>, tensor<2x1xf32>) -> tensor<4x128x1xf32>
  func.return %4 : tensor<4x128x1xf32>
  // CHECK: "tfl.fully_connected"
}

// CHECK-LABEL: Batchmatmul2Fullyconnected_qint4_per_channel
// CHECK-NOT: "tfl.batch_matmul"
func.func @Batchmatmul2Fullyconnected_qint4_per_channel(%arg0: tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, %arg1: tensor<2x2x!quant.uniform<i4<-7:7>:f32:1, {0.014552096836268902,0.012686832807958126}>>) -> (tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>) {
  %2 = "tfl.batch_matmul"(%arg0, %arg1) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, tensor<2x2x!quant.uniform<i4<-7:7>:f32:1, {0.014552096836268902,0.012686832807958126}>>) -> tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
  func.return %2 : tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
  // CHECK: %[[TRANSPOSED_X:.*]] = "tfl.transpose"
  // CHECK-SAME: (tensor<2x2x!quant.uniform<i4<-7:7>:f32:1, {0.014552096836268902,0.012686832807958126}>>, tensor<2xi32>) -> tensor<2x2x!quant.uniform<i4<-7:7>:f32:0, {0.014552096836268902,0.012686832807958126}>>
  // CHECK: %[[FC_RES:.*]] = "tfl.fully_connected"(%arg0, %[[TRANSPOSED_X]]
  // CHECK-SAME: <{fused_activation_function = "NONE", keep_num_dims = true, weights_format = "DEFAULT"}> : (tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, tensor<2x2x!quant.uniform<i4<-7:7>:f32:0, {0.014552096836268902,0.012686832807958126}>>, none) -> tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
  // CHECK-NEXT: return %[[FC_RES]]
}

// CHECK-LABEL: Batchmatmul2Fullyconnected_qint4_per_tensor
func.func @Batchmatmul2Fullyconnected_qint4_per_tensor(%arg0: tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, %arg1: tensor<2x2x!quant.uniform<i4:f32, 0.014552096836268902>>) -> (tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>) {
  // CHECK-NOT: "tfl.batch_matmul"
  %2 = "tfl.batch_matmul"(%arg0, %arg1) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, tensor<2x2x!quant.uniform<i4:f32, 0.014552096836268902>>) -> tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
  func.return %2 : tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
}

// CHECK-LABEL: Batchmatmul2Fullyconnected_qint4_rank_3
func.func @Batchmatmul2Fullyconnected_qint4_rank_3(%arg0: tensor<10x1x2x!quant.uniform<i8:f32, 0.01524067297577858>>, %arg1: tensor<10x2x2x!quant.uniform<i4:f32, 0.014552096836268902>>) -> (tensor<10x1x2x!quant.uniform<i8:f32, 0.016966061666607857>>) {
  // CHECK: "tfl.batch_matmul"
  %2 = "tfl.batch_matmul"(%arg0, %arg1) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<10x1x2x!quant.uniform<i8:f32, 0.01524067297577858>>, tensor<10x2x2x!quant.uniform<i4:f32, 0.014552096836268902>>) -> tensor<10x1x2x!quant.uniform<i8:f32, 0.016966061666607857>>
  func.return %2 : tensor<10x1x2x!quant.uniform<i8:f32, 0.016966061666607857>>
}

// CHECK-LABEL: Batchmatmul2Fullyconnected_qint8
func.func @Batchmatmul2Fullyconnected_qint8(%arg0: tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, %arg1: tensor<2x2x!quant.uniform<i8:f32, 0.014552096836268902>>) -> (tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>) {
  // CHECK-NOT: "tfl.batch_matmul"
  %2 = "tfl.batch_matmul"(%arg0, %arg1) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<10x2x!quant.uniform<i8:f32, 0.01524067297577858>>, tensor<2x2x!quant.uniform<i8:f32, 0.014552096836268902>>) -> tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
  func.return %2 : tensor<10x2x!quant.uniform<i8:f32, 0.016966061666607857>>
}

// CHECK-LABEL: BatchmatmulToReduceSumI32
// CHECK-NOT: "tfl.batch_matmul"
func.func @BatchmatmulToReduceSumI32(%arg0: tensor<1x16384x257xi32>) -> (tensor<1x1x257xi32>) {
  %0 = arith.constant dense<1> : tensor<1x1x16384xi32>
  %1 = "tfl.batch_matmul"(%0, %arg0) {adj_x = false, adj_y = false} : (tensor<1x1x16384xi32>, tensor<1x16384x257xi32>) -> tensor<1x1x257xi32>
  func.return %1 : tensor<1x1x257xi32>
  // CHECK: %[[CONST_DIM:.*]] = "tfl.pseudo_const"() <{value = dense<1> : tensor<1xi32>}> : () -> tensor<1xi32>
  // CHECK: %[[RED:.*]] = "tfl.sum"(%arg0, %[[CONST_DIM]]) <{keep_dims = true}> : (tensor<1x16384x257xi32>, tensor<1xi32>) -> tensor<1x1x257xi32>
}

// CHECK-LABEL: BatchmatmulToReduceSumF32
// CHECK-NOT: "tfl.batch_matmul"
func.func @BatchmatmulToReduceSumF32(%arg0: tensor<1x16384x257xf32>) -> (tensor<1x1x257xf32>) {
  %0 = arith.constant dense<1.0> : tensor<1x1x16384xf32>
  %1 = "tfl.batch_matmul"(%0, %arg0) {adj_x = false, adj_y = false} : (tensor<1x1x16384xf32>, tensor<1x16384x257xf32>) -> tensor<1x1x257xf32>
  func.return %1 : tensor<1x1x257xf32>
  // CHECK: %[[CONST_DIM:.*]] = "tfl.pseudo_const"() <{value = dense<1> : tensor<1xi32>}> : () -> tensor<1xi32>
  // CHECK: %[[RED:.*]] = "tfl.sum"(%arg0, %[[CONST_DIM]]) <{keep_dims = true}> : (tensor<1x16384x257xf32>, tensor<1xi32>) -> tensor<1x1x257xf32>
}

// CHECK-LABEL: FuseBatchMatmulToTransposeNoBatchDims
func.func @FuseBatchMatmulToTransposeNoBatchDims(%arg0: tensor<2048x32x128xf32>, %arg1: tensor<4x128xf32>) -> tensor<4x65536xf32> {
  %36 = "tfl.pseudo_const"() <{value = dense<[2, 0, 1]> : tensor<3xi32>}> : () -> tensor<3xi32>
  %37 = "tfl.transpose"(%arg0, %36) : (tensor<2048x32x128xf32>, tensor<3xi32>) -> tensor<128x2048x32xf32>
  %38 = "tfl.pseudo_const"() <{value = dense<[128, 65536]> : tensor<2xi32>}> : () -> tensor<2xi32>
  %39 = "tfl.reshape"(%37, %38) : (tensor<128x2048x32xf32>, tensor<2xi32>) -> tensor<128x65536xf32>
  %41 = "tfl.batch_matmul"(%arg1, %39) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<4x128xf32>, tensor<128x65536xf32>) -> tensor<4x65536xf32>
  return %41 : tensor<4x65536xf32>
  // CHECK-NOT: "tfl.transpose"
}

// CHECK-LABEL: FuseBatchMatmulToTransposeWithBatchDims
func.func @FuseBatchMatmulToTransposeWithBatchDims(%arg0: tensor<2048x1x8x32x32xf32>, %arg1: tensor<2048x1x2x32xf32>) -> tensor<2048x1x2x256xf32> {
  %104 = "tfl.pseudo_const"() <{value = dense<[0, 1, 4, 2, 3]> : tensor<5xi32>}> : () -> tensor<5xi32>
  %106 = "tfl.pseudo_const"() <{value = dense<[2048, 1, 32, 256]> : tensor<4xi32>}> : () -> tensor<4xi32>
  %202 = "tfl.transpose"(%arg0, %104) : (tensor<2048x1x8x32x32xf32>, tensor<5xi32>) -> tensor<2048x1x32x8x32xf32>
  %203 = "tfl.reshape"(%202, %106) : (tensor<2048x1x32x8x32xf32>, tensor<4xi32>) -> tensor<2048x1x32x256xf32>
  %204 = "tfl.batch_matmul"(%arg1, %203) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<2048x1x2x32xf32>, tensor<2048x1x32x256xf32>) -> tensor<2048x1x2x256xf32>
  return %204 : tensor<2048x1x2x256xf32>
  // CHECK-NOT: "tfl.transpose"
}

// CHECK-LABEL: FuseTransposeFCRhsToBatchMatmulDequantReshape
func.func @FuseTransposeFCRhsToBatchMatmulDequantReshape(%arg0: tensor<16x1024xf32>, %arg1: tensor<1024x128x!quant.uniform<i8:f32, 0.024986599940879671:92>>, %arg2: none) -> tensor<16x128xf32> {
  %cst = arith.constant dense<[1, 0]> : tensor<2xi32>
  %cst_shape = arith.constant dense<[1024, 128]> : tensor<2xi32>
  %0 = "tfl.dequantize"(%arg1) : (tensor<1024x128x!quant.uniform<i8:f32, 0.024986599940879671:92>>) -> tensor<1024x128xf32>
  %1 = "tfl.reshape"(%0, %cst_shape) : (tensor<1024x128xf32>, tensor<2xi32>) -> tensor<1024x128xf32>
  %2 = "tfl.transpose"(%1, %cst) : (tensor<1024x128xf32>, tensor<2xi32>) -> tensor<128x1024xf32>
  // CHECK: "tfl.fully_connected"
  // CHECK-NOT: "tfl.batch_matmul"
  %3 = "tfl.fully_connected"(%arg0, %2, %arg2) {asymmetric_quantize_inputs = false, fused_activation_function = "NONE", keep_num_dims = false, weights_format = "DEFAULT"} : (tensor<16x1024xf32>, tensor<128x1024xf32>, none) -> tensor<16x128xf32>
  func.return %3 : tensor<16x128xf32>
}

// CHECK-LABEL: FuseBatchMatmulToTransposeNegative
func.func @FuseBatchMatmulToTransposeNegative(%arg0: tensor<2048x32x1x8x2xf32>, %arg1: tensor<2048x1x32x2xf32>) -> tensor<2048x1x32x256xf32> {
  %88 = "tfl.pseudo_const"() <{value = dense<[0, 2, 4, 1, 3]> : tensor<5xi32>}> : () -> tensor<5xi32>
  %90 = "tfl.pseudo_const"() <{value = dense<[2048, 1, 2, 256]> : tensor<4xi32>}> : () -> tensor<4xi32>
  %194 = "tfl.transpose"(%arg0, %88) : (tensor<2048x32x1x8x2xf32>, tensor<5xi32>) -> tensor<2048x1x2x32x8xf32>
  %195 = "tfl.reshape"(%194, %90) : (tensor<2048x1x2x32x8xf32>, tensor<4xi32>) -> tensor<2048x1x2x256xf32>
  %196 = "tfl.batch_matmul"(%arg1, %195) <{adj_x = false, adj_y = false, asymmetric_quantize_inputs = false}> : (tensor<2048x1x32x2xf32>, tensor<2048x1x2x256xf32>) -> tensor<2048x1x32x256xf32>
  return %196 : tensor<2048x1x32x256xf32>
  // CHECK: "tfl.transpose"
}