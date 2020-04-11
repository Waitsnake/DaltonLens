//
// Copyright (c) 2017, Nicolas Burrus
// This software may be modified and distributed under the terms
// of the BSD license.  See the LICENSE file for details.
//

#import <Foundation/Foundation.h>

#import <CoreImage/CoreImage.h>

#import "MetalRenderer.h"

#import "MetalRendererImpl.h"

#include <cstdint>

@interface DLMetalRenderer()
{
    DLMetalProcessor* _processor;
    dl::MetalDataOnScreen _mtl;
}
@end

@implementation DLMetalRenderer

- (instancetype)initWithProcessor:(DLMetalProcessor*)processor
{
    self = [super init];
    if (self)
    {
        _processor = processor;
        _mtl.initialize(processor.mtlDevice);
    }
    return self;
}

-(DLMetalUniforms*) uniformsBuffer
{
    return static_cast<DLMetalUniforms*>([_mtl.uniformBuffer contents]);
}

- (void)renderWithScreenImage:(id<MTLTexture>)screenImage
                commandBuffer:(id<MTLCommandBuffer>)commandBuffer
         renderPassDescriptor:(MTLRenderPassDescriptor*)rpd
{
     
    //rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    auto pipelineState = _processor.filteringPipeline;
    
    auto commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
    [commandEncoder setRenderPipelineState:pipelineState];
    [commandEncoder setVertexBuffer:_mtl.quadVertexBuffer offset:0 atIndex:0];
    [commandEncoder setFragmentTexture:screenImage atIndex:0];
    [commandEncoder setFragmentBuffer:_mtl.uniformBuffer offset:0 atIndex: 0];
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
    [commandEncoder endEncoding];
}

@end

