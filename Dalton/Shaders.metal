//
// Copyright (c) 2017, Nicolas Burrus
// This software may be modified and distributed under the terms
// of the BSD license.  See the LICENSE file for details.
//

#undef USE_ONE_NIGHT_HACK

// use DCK16L, DCK17L, DCK18L(recommended) or USE_DCK19L (experimental)
#define USE_DCK18L

#include <metal_stdlib>
using namespace metal;

float3 yCbCrFromSRGBA (float4 srgba);
float4 sRGBAfromYCbCr (float3 yCbCr, float alpha);

float3 lmsFromSRGBA (float4 srgba);
float4 sRGBAFromLms (float3 lms, float alpha);
float4 sRGBAFromLms_no_clamp (float3 lms, float alpha);

float3 HCVFromRGB(float3 RGB);
float3 RGBFromHUE(float H);

float3 HSLFromSRGBA(float4 srgba);
float4 sRGBAFromHSL(float3 HSL, float alpha);

float3 HSVFromSRGBA (float4 srgba);
float4 sRGBAFromHSV(float3 HSV, float alpha);

float3 applyProtanope (float3 lms);
float3 applyDeuteranope (float3 lms);
float3 applyTritanope (float3 lms);

float4 applyProtanomalyRgb (float4 srgba, int severity);
float4 applyDeuteranomalyRgb (float4 srgba, int severity);
float4 applyTritanomalyRgb (float4 srgba, int severity);

float4 daltonizeV1 (float4 srgba, float4 srgbaSimulated);

// AA = antialiasing.
bool colorsAreCompatibleWithAA(float r0, float g0, float r1, float g1);

// Compared very bright colors is usually not meaningful, since any color will be almost
// white when antialiased with a white background.
bool canMakeSignificantComparisonBetweenAAColors (float r0, float g0, float r1, float g1);

constexpr sampler defaultSampler(coord::normalized,
                                 address::clamp_to_edge,
                                 filter::linear);

constant float hsxEpsilon = 1e-10;

struct Uniforms
{
    float4 srgbaUnderCursor;
    int frameCount; // for animations
    int severity;
    float dcklSeverity;
    float dcklRG;
    float dcklRB;
    float dcklGB;
    float dcklSoftCompress;
    float dcklPreserveLuma;
    int dcklSimu;
};

struct VertexIn
{
    float4 position [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

struct VertexOut
{
    float4 position [[position]] [[attribute(0)]];
    float2 texCoords [[attribute(1)]];
};

vertex VertexOut vertex_quad(VertexIn vert [[stage_in]],
                          uint vid [[vertex_id]])
{
    VertexOut out;
    out.position = vert.position;
    out.texCoords = vert.texCoords;
    return out;
}

// Adapted from http://www.chilliant.com/rgb2hsv.html

float3 HCVFromRGB(float3 RGB)
{
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + hsxEpsilon) + Q.z);
    return float3(H, C, Q.x);
}

float3 HSLFromSRGBA(float4 srgba)
{
    // FIXME: this is ignoring gamma and treating it like linearRGB
    
    float3 HCV = HCVFromRGB(srgba.rgb);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1 - abs(L * 2 - 1) + hsxEpsilon);
    return float3(HCV.x, S, L);
}

float3 HSVFromSRGBA (float4 srgba)
{
    // FIXME: this is ignoring gamma and treating it like linearRGB
    
    float3 HCV = HCVFromRGB(srgba.xyz);
    float S = HCV.y / (HCV.z + hsxEpsilon);
    return float3(HCV.x, S, HCV.z);
}

float3 RGBFromHUE(float H)
{
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

float4 sRGBAFromHSV(float3 HSV, float alpha)
{
    float3 RGB = RGBFromHUE(HSV.x);
    return float4(((RGB - 1) * HSV.y + 1) * HSV.z, alpha);
}

float4 sRGBAFromHSL(float3 HSL, float alpha)
{
    float3 RGB = RGBFromHUE(HSL.x);
    float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
    return float4((RGB - 0.5) * C + HSL.z, alpha);
}

float3 yCbCrFromSRGBA (float4 srgba)
{
    // FIXME: this is ignoring gamma and treating it like linearRGB
    
    float y =   0.57735027*srgba.r + 0.57735027*srgba.g + 0.57735027*srgba.b;
    float cr =  0.70710678*srgba.r - 0.70710678*srgba.g;
    float cb = -0.40824829*srgba.r - 0.40824829*srgba.g + 0.81649658*srgba.b;
    return float3(y,cb,cr);
}

float4 sRGBAfromYCbCr (float3 yCbCr, float alpha)
{
    // FIXME: this is ignoring gamma and treating it like linearRGB
    
    float4 srgbaOut;
    
    float y = yCbCr.x;
    float cb = yCbCr.y;
    float cr = yCbCr.z;
    
    srgbaOut.r = clamp(5.77350269e-01*y + 7.07106781e-01*cr - 4.08248290e-01*cb, 0.0, 1.0);
    srgbaOut.g = clamp(5.77350269e-01*y - 7.07106781e-01*cr - 4.08248290e-01*cb, 0.0, 1.0);
    srgbaOut.b = clamp(5.77350269e-01*y +            0.0*cr + 8.16496581e-01*cb, 0.0, 1.0);
    srgbaOut.a = alpha;
    return srgbaOut;
}

fragment float4 fragment_passthrough(VertexOut vert [[stage_in]],
                                     texture2d<float> screenTexture [[texture(0)]])
{
    float4 sampledColor = screenTexture.sample(defaultSampler, vert.texCoords);
    return sampledColor;
}

fragment float4 fragment_swapCbCr(VertexOut vert [[stage_in]],
                                  texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    
    float3 yCbCr = yCbCrFromSRGBA(srgba);
    float3 transformedYCbCr = yCbCr;
    transformedYCbCr.x = yCbCr.x;
    transformedYCbCr.y = yCbCr.z;
    transformedYCbCr.z = yCbCr.y;
    
    float4 srgbaOut = sRGBAfromYCbCr (transformedYCbCr, 1.0);
    return srgbaOut;
}

fragment float4 fragment_swapAndFlipCbCr(VertexOut vert [[stage_in]],
                                         texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    
    float3 yCbCr = yCbCrFromSRGBA(srgba);
    float3 transformedYCbCr = yCbCr;
    transformedYCbCr.x = yCbCr.x;
    transformedYCbCr.y = -yCbCr.z; // flip Cb
    transformedYCbCr.z = yCbCr.y;
    
    float4 srgbaOut = sRGBAfromYCbCr (transformedYCbCr, 1.0);
    return srgbaOut;
}

fragment float4 fragment_invertHue(VertexOut vert [[stage_in]],
                                   texture2d<float> screenTexture [[texture(0)]])
{
    // Invert the value component in HSV space (equivalent of the gimp value invert filter).
    // This tends to downweight colors with one strong RGB channel, where max(RGB) is high.
    
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 hsv = HSVFromSRGBA(srgba);
    hsv.z = 1.0 - hsv.z;
    float4 srgbaOut = sRGBAFromHSV (hsv, srgba.a);
    return srgbaOut;
}

fragment float4 fragment_invertLightness(VertexOut vert [[stage_in]],
                                         texture2d<float> screenTexture [[texture(0)]])
{
    // Invert the lightness component in HSL space. This tends to downweight
    // pure colors with very strong difference between channels, where min(RGB) is
    // small and max(RGB) is high.
    
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 hsl = HSLFromSRGBA(srgba);
    hsl.z = 1.0 - hsl.z;
    float4 srgbaOut = sRGBAFromHSL (hsl, srgba.a);
    return srgbaOut;
}

fragment float4 fragment_invertRGB(VertexOut vert [[stage_in]],
                                   texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaOut;
    srgbaOut.r = 1.0 - srgba.r;
    srgbaOut.g = 1.0 - srgba.g;
    srgbaOut.b = 1.0 - srgba.b;
    srgbaOut.a = srgba.a;
    return srgbaOut;
}

float3 lmsFromSRGBA (float4 srgba)
{
    //    17.8824, 43.5161, 4.11935,
    //    3.45565, 27.1554, 3.86714,
    //    0.0299566, 0.184309, 1.46709
    
    float3 lms;
    lms[0] = 17.8824*srgba.r + 43.5161*srgba.g + 4.11935*srgba.b;
    lms[1] = 3.45565*srgba.r + 27.1554*srgba.g + 3.86714*srgba.b;
    lms[2] = 0.0299566*srgba.r + 0.184309*srgba.g + 1.46709*srgba.b;
    return lms;
}

float4 sRGBAFromLms (float3 lms, float alpha)
{
    //    0.0809445    -0.130504     0.116721
    //    -0.0102485    0.0540193    -0.113615
    //    -0.000365297  -0.00412162     0.693511
    
    float4 srgbaOut;
    srgbaOut.r = clamp(0.0809445*lms[0] - 0.130504*lms[1] + 0.116721*lms[2], 0.0, 1.0);
    srgbaOut.g = clamp(-0.0102485*lms[0] + 0.0540193*lms[1] - 0.113615*lms[2], 0.0, 1.0);
    srgbaOut.b = clamp(-0.000365297*lms[0] - 0.00412162*lms[1] + 0.693511*lms[2], 0.0, 1.0);
    srgbaOut.a = alpha;
    return srgbaOut;
}

// clamp free sRGBAFromLms for DCK17L to avoid information lost before calculation of error differences
float4 sRGBAFromLms_no_clamp (float3 lms, float alpha)
{
    //    0.0809445    -0.130504     0.116721
    //    -0.0102485    0.0540193    -0.113615
    //    -0.000365297  -0.00412162     0.693511
    
    float4 srgbaOut;
    srgbaOut.r = 0.0809445*lms[0] - 0.130504*lms[1] + 0.116721*lms[2];
    srgbaOut.g = -0.0102485*lms[0] + 0.0540193*lms[1] - 0.113615*lms[2];
    srgbaOut.b = -0.000365297*lms[0] - 0.00412162*lms[1] + 0.693511*lms[2];
    srgbaOut.a = alpha;
    return srgbaOut;
}

float3 applyProtanope (float3 lms)
{
    //    p.l = /* 0*p.l + */ 2.02344*p.m - 2.52581*p.s;
    float3 lmsTransformed = lms;
    lmsTransformed[0] = 2.02344*lms[1] - 2.52581*lms[2];
    return lmsTransformed;
}

float3 applyDeuteranope (float3 lms)
{
    //    p.m = 0.494207*p.l /* + 0*p.m */ + 1.24827*p.s;
    float3 lmsTransformed = lms;
    lmsTransformed[1] = 0.494207*lms[0] + 1.24827*lms[2];
    return lmsTransformed;
}

float3 applyTritanope (float3 lms)
{
    //    p.s = -0.395913*p.l + 0.801109*p.m /* + 0*p.s */;
    float3 lmsTransformed = lms;
    lmsTransformed[2] = -0.395913*lms[0] + 0.801109*lms[1];
    return lmsTransformed;
}

float4 applyProtanomalyRgb (float4 srgba, int severity)
{
    float4 srgbaTransformed = srgba;

#ifdef USE_ONE_NIGHT_HACK
    /*
      Matrix values for Color Defects in RGB Space "Color-Matrix" by www.colorjack.com (the "one-night hack") https://web.archive.org/web/20081014161121/http://www.colorjack.com/labs/colormatrix/
     
     'Normal':[1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Protanopia':[0.567,0.433,0,0,0, 0.558,0.442,0,0,0, 0,0.242,0.758,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Protanomaly':[0.817,0.183,0,0,0, 0.333,0.667,0,0,0, 0,0.125,0.875,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Deuteranopia':[0.625,0.375,0,0,0, 0.7,0.3,0,0,0, 0,0.3,0.7,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Deuteranomaly':[0.8,0.2,0,0,0, 0.258,0.742,0,0,0, 0,0.142,0.858,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Tritanopia':[0.95,0.05,0,0,0, 0,0.433,0.567,0,0, 0,0.475,0.525,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Tritanomaly':[0.967,0.033,0,0,0, 0,0.733,0.267,0,0, 0,0.183,0.817,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Achromatopsia':[0.299,0.587,0.114,0,0, 0.299,0.587,0.114,0,0, 0.299,0.587,0.114,0,0, 0,0,0,1,0, 0,0,0,0,1],
     'Achromatomaly':[0.618,0.320,0.062,0,0, 0.163,0.775,0.062,0,0, 0.163,0.320,0.516,0,0
     */
    
    // from "Color-Matrix" by www.colorjack.com
    // it is said that the "one-night hack" should not be used any more
    srgbaTransformed[0] = 0.817*srgba[0] + 0.183*srgba[1] +   0.0*srgba[2];
    srgbaTransformed[1] = 0.333*srgba[0] + 0.667*srgba[1] +   0.0*srgba[2];
    srgbaTransformed[2] =   0.0*srgba[0] + 0.125*srgba[1] + 0.875*srgba[2];
    
#else
    
    /*
    values for different CVD severity levels are from Machado CVD
     https://github.com/mpetroff/color-sets/blob/master/color_conversions.py
     https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html
     */
    
    // Machado with severity levels for protanomaly
    switch (severity)
    {
        case 0:
            srgbaTransformed[0] = 1*srgba[0] + 0*srgba[1] + 0*srgba[2];
            srgbaTransformed[1] = 0*srgba[0] + 1*srgba[1] + 0*srgba[2];
            srgbaTransformed[2] = 0*srgba[0] + 0*srgba[1] + 1*srgba[2];
            break;
                
        case 1:
            srgbaTransformed[0] =  0.856167*srgba[0] +  0.182038*srgba[1] + -0.038205*srgba[2];
            srgbaTransformed[1] =  0.029342*srgba[0] +  0.955115*srgba[1] +  0.015544*srgba[2];
            srgbaTransformed[2] = -0.002880*srgba[0] + -0.001563*srgba[1] +  1.004443*srgba[2];
            break;
    
        case 2:
            srgbaTransformed[0] =  0.734766*srgba[0] +  0.334872*srgba[1] + -0.069637*srgba[2];
            srgbaTransformed[1] =  0.051840*srgba[0] +  0.919198*srgba[1] +  0.028963*srgba[2];
            srgbaTransformed[2] = -0.004928*srgba[0] + -0.004209*srgba[1] +  1.009137*srgba[2];
            break;

        
        case 3:
            srgbaTransformed[0] =  0.630323*srgba[0] +  0.465641*srgba[1] + -0.095964*srgba[2];
            srgbaTransformed[1] =  0.069181*srgba[0] +  0.890046*srgba[1] +  0.040773*srgba[2];
            srgbaTransformed[2] = -0.006308*srgba[0] + -0.007724*srgba[1] +  1.014032*srgba[2];
            break;

        case 4:
            srgbaTransformed[0] =  0.539009*srgba[0] +  0.579343*srgba[1] + -0.118352*srgba[2];
            srgbaTransformed[1] =  0.082546*srgba[0] +  0.866121*srgba[1] +  0.051332*srgba[2];
            srgbaTransformed[2] = -0.007136*srgba[0] + -0.011959*srgba[1] +  1.019095*srgba[2];
            break;
    
        case 5:
            srgbaTransformed[0] =  0.458064*srgba[0] +  0.679578*srgba[1] + -0.137642*srgba[2];
            srgbaTransformed[1] =  0.092785*srgba[0] +  0.846313*srgba[1] +  0.060902*srgba[2];
            srgbaTransformed[2] = -0.007494*srgba[0] + -0.016807*srgba[1] +  1.024301*srgba[2];
            break;
        
        case 6:
            srgbaTransformed[0] =  0.385450*srgba[0] +  0.769005*srgba[1] + -0.154455*srgba[2];
            srgbaTransformed[1] =  0.100526*srgba[0] +  0.829802*srgba[1] +  0.069673*srgba[2];
            srgbaTransformed[2] = -0.007442*srgba[0] + -0.022190*srgba[1] +  1.029632*srgba[2];
            break;
    
        case 7:
            srgbaTransformed[0] =  0.319627*srgba[0] +  0.849633*srgba[1] + -0.169261*srgba[2];
            srgbaTransformed[1] =  0.106241*srgba[0] +  0.815969*srgba[1] +  0.077790*srgba[2];
            srgbaTransformed[2] = -0.007025*srgba[0] + -0.028051*srgba[1] +  1.035076*srgba[2];
            break;
    
        case 8:
            srgbaTransformed[0] =  0.259411*srgba[0] +  0.923008*srgba[1] + -0.182420*srgba[2];
            srgbaTransformed[1] =  0.110296*srgba[0] +  0.804340*srgba[1] +  0.085364*srgba[2];
            srgbaTransformed[2] = -0.006276*srgba[0] + -0.034346*srgba[1] +  1.040622*srgba[2];
            break;

        case 9:
            srgbaTransformed[0] =  0.203876*srgba[0] +  0.990338*srgba[1] + -0.194214*srgba[2];
            srgbaTransformed[1] =  0.112975*srgba[0] +  0.794542*srgba[1] +  0.092483*srgba[2];
            srgbaTransformed[2] = -0.005222*srgba[0] + -0.041043*srgba[1] +  1.046265*srgba[2];
            break;
    
        case 10:
            srgbaTransformed[0] =  0.152286*srgba[0] +  1.052583*srgba[1] + -0.204868*srgba[2];
            srgbaTransformed[1] =  0.114503*srgba[0] +  0.786281*srgba[1] +  0.099216*srgba[2];
            srgbaTransformed[2] = -0.003882*srgba[0] + -0.048116*srgba[1] +  1.051998*srgba[2];
            break;
            
        default:
            srgbaTransformed[0] = 1*srgba[0] + 0*srgba[1] + 0*srgba[2];
            srgbaTransformed[1] = 0*srgba[0] + 1*srgba[1] + 0*srgba[2];
            srgbaTransformed[2] = 0*srgba[0] + 0*srgba[1] + 1*srgba[2];
            break;
    }
#endif
    
    srgbaTransformed[3] =                                                       1.0*srgba[3];
    return srgbaTransformed;
}

float4 applyDeuteranomalyRgb (float4 srgba, int severity)
{
    float4 srgbaTransformed = srgba;
#ifdef USE_ONE_NIGHT_HACK
    // from "Color-Matrix" by www.colorjack.com
    // it is said that the "one-night hack" should not be used any more
    srgbaTransformed[0] =   0.8*srgba[0] +   0.2*srgba[1] +   0.0*srgba[2];
    srgbaTransformed[1] = 0.258*srgba[0] + 0.742*srgba[1] +   0.0*srgba[2];
    srgbaTransformed[2] =   0.0*srgba[0] + 0.142*srgba[1] + 0.858*srgba[2];
#else
    // Machado with severity levels for deuteranomaly
    switch (severity)
    {
        case 0:
            srgbaTransformed[0] = 1*srgba[0] + 0*srgba[1] + 0*srgba[2];
            srgbaTransformed[1] = 0*srgba[0] + 1*srgba[1] + 0*srgba[2];
            srgbaTransformed[2] = 0*srgba[0] + 0*srgba[1] + 1*srgba[2];
            break;
                
        case 1:
            srgbaTransformed[0] =  0.866435*srgba[0] +  0.177704*srgba[1] + -0.044139*srgba[2];
            srgbaTransformed[1] =  0.049567*srgba[0] +  0.939063*srgba[1] +  0.011370*srgba[2];
            srgbaTransformed[2] = -0.003453*srgba[0] +  0.007233*srgba[1] +  0.996220*srgba[2];
            break;
    
        case 2:
            srgbaTransformed[0] =  0.760729*srgba[0] +  0.319078*srgba[1] + -0.079807*srgba[2];
            srgbaTransformed[1] =  0.090568*srgba[0] +  0.889315*srgba[1] +  0.020117*srgba[2];
            srgbaTransformed[2] = -0.006027*srgba[0] +  0.013325*srgba[1] +  0.992702*srgba[2];
            break;

        case 3:
            srgbaTransformed[0] =  0.675425*srgba[0] +  0.433850*srgba[1] + -0.109275*srgba[2];
            srgbaTransformed[1] =  0.125303*srgba[0] +  0.847755*srgba[1] +  0.026942*srgba[2];
            srgbaTransformed[2] = -0.007950*srgba[0] +  0.018572*srgba[1] +  0.989378*srgba[2];
            break;

        case 4:
            srgbaTransformed[0] =  0.605511*srgba[0] +  0.528560*srgba[1] + -0.134071*srgba[2];
            srgbaTransformed[1] =  0.155318*srgba[0] +  0.812366*srgba[1] +  0.032316*srgba[2];
            srgbaTransformed[2] = -0.009376*srgba[0] +  0.023176*srgba[1] +  0.986200*srgba[2];
            break;
    
        case 5:
            srgbaTransformed[0] =  0.547494*srgba[0] +  0.607765*srgba[1] + -0.155259*srgba[2];
            srgbaTransformed[1] =  0.181692*srgba[0] +  0.781742*srgba[1] +  0.036566*srgba[2];
            srgbaTransformed[2] = -0.010410*srgba[0] +  0.027275*srgba[1] +  0.983136*srgba[2];
            break;
        
        case 6:
            srgbaTransformed[0] =  0.498864*srgba[0] +  0.674741*srgba[1] + -0.173604*srgba[2];
            srgbaTransformed[1] =  0.205199*srgba[0] +  0.754872*srgba[1] +  0.039929*srgba[2];
            srgbaTransformed[2] = -0.011131*srgba[0] +  0.030969*srgba[1] +  0.980162*srgba[2];
            break;
    
        case 7:
            srgbaTransformed[0] =  0.457771*srgba[0] +  0.731899*srgba[1] + -0.189670*srgba[2];
            srgbaTransformed[1] =  0.226409*srgba[0] +  0.731012*srgba[1] +  0.042579*srgba[2];
            srgbaTransformed[2] = -0.011595*srgba[0] +  0.034333*srgba[1] +  0.977261*srgba[2];
            break;
    
        case 8:
            srgbaTransformed[0] =  0.422823*srgba[0] +  0.781057*srgba[1] + -0.203881*srgba[2];
            srgbaTransformed[1] =  0.245752*srgba[0] +  0.709602*srgba[1] +  0.044646*srgba[2];
            srgbaTransformed[2] = -0.011843*srgba[0] +  0.037423*srgba[1] +  0.974421*srgba[2];
            break;

        case 9:
            srgbaTransformed[0] =  0.392952*srgba[0] +  0.823610*srgba[1] + -0.216562*srgba[2];
            srgbaTransformed[1] =  0.263559*srgba[0] +  0.690210*srgba[1] +  0.046232*srgba[2];
            srgbaTransformed[2] = -0.011910*srgba[0] +  0.040281*srgba[1] +  0.971630*srgba[2];
            break;
    
        case 10:
            srgbaTransformed[0] =  0.367322*srgba[0] +  0.860646*srgba[1] + -0.227968*srgba[2];
            srgbaTransformed[1] =  0.280085*srgba[0] +  0.672501*srgba[1] +  0.047413*srgba[2];
            srgbaTransformed[2] = -0.011820*srgba[0] +  0.042940*srgba[1] +  0.968881*srgba[2];
            break;
        
        default:
            srgbaTransformed[0] = 1*srgba[0] + 0*srgba[1] + 0*srgba[2];
            srgbaTransformed[1] = 0*srgba[0] + 1*srgba[1] + 0*srgba[2];
            srgbaTransformed[2] = 0*srgba[0] + 0*srgba[1] + 1*srgba[2];
            break;
    }
#endif
    srgbaTransformed[3] =                                                   1.0*srgba[3];
    return srgbaTransformed;
}

float4 applyTritanomalyRgb (float4 srgba, int severity)
{
    float4 srgbaTransformed = srgba;
#ifdef USE_ONE_NIGHT_HACK
    // from "Color-Matrix" by www.colorjack.com
    // it is said that the "one-night hack" should not be used any more
    srgbaTransformed[0] = 0.967*srgba[0] + 0.033*srgba[1] +   0.0*srgba[2];
    srgbaTransformed[1] =   0.0*srgba[0] + 0.733*srgba[1] + 0.267*srgba[2];
    srgbaTransformed[2] =   0.0*srgba[0] + 0.183*srgba[1] + 0.817*srgba[2];
#else
    // Machado with severity levels for tritanomaly
    switch (severity)
    {
        case 0:
            srgbaTransformed[0] = 1*srgba[0] + 0*srgba[1] + 0*srgba[2];
            srgbaTransformed[1] = 0*srgba[0] + 1*srgba[1] + 0*srgba[2];
            srgbaTransformed[2] = 0*srgba[0] + 0*srgba[1] + 1*srgba[2];
            break;
                
        case 1:
            srgbaTransformed[0] =  0.926670*srgba[0] +  0.092514*srgba[1] + -0.019184*srgba[2];
            srgbaTransformed[1] =  0.021191*srgba[0] +  0.964503*srgba[1] +  0.014306*srgba[2];
            srgbaTransformed[2] =  0.008437*srgba[0] +  0.054813*srgba[1] +  0.936750*srgba[2];
            break;
    
        case 2:
            srgbaTransformed[0] =  0.895720*srgba[0] +  0.133330*srgba[1] + -0.029050*srgba[2];
            srgbaTransformed[1] =  0.029997*srgba[0] +  0.945400*srgba[1] +  0.024603*srgba[2];
            srgbaTransformed[2] =  0.013027*srgba[0] +  0.104707*srgba[1] +  0.882266*srgba[2];
            break;

        case 3:
            srgbaTransformed[0] =  0.905871*srgba[0] +  0.127791*srgba[1] + -0.033662*srgba[2];
            srgbaTransformed[1] =  0.026856*srgba[0] +  0.941251*srgba[1] +  0.031893*srgba[2];
            srgbaTransformed[2] =  0.013410*srgba[0] +  0.148296*srgba[1] +  0.838294*srgba[2];
            break;

        case 4:
            srgbaTransformed[0] =  0.948035*srgba[0] +  0.089490*srgba[1] + -0.037526*srgba[2];
            srgbaTransformed[1] =  0.014364*srgba[0] +  0.946792*srgba[1] +  0.038844*srgba[2];
            srgbaTransformed[2] =  0.010853*srgba[0] +  0.193991*srgba[1] +  0.795156*srgba[2];
            break;
    
        case 5:
            srgbaTransformed[0] =  1.017277*srgba[0] +  0.027029*srgba[1] + -0.044306*srgba[2];
            srgbaTransformed[1] = -0.006113*srgba[0] +  0.958479*srgba[1] +  0.047634*srgba[2];
            srgbaTransformed[2] =  0.006379*srgba[0] +  0.248708*srgba[1] +  0.744913*srgba[2];
            break;
        
        case 6:
            srgbaTransformed[0] =  1.104996*srgba[0] + -0.046633*srgba[1] + -0.058363*srgba[2];
            srgbaTransformed[1] = -0.032137*srgba[0] +  0.971635*srgba[1] +  0.060503*srgba[2];
            srgbaTransformed[2] =  0.001336*srgba[0] +  0.317922*srgba[1] +  0.680742*srgba[2];
            break;
    
        case 7:
            srgbaTransformed[0] =  1.193214*srgba[0] + -0.109812*srgba[1] + -0.083402*srgba[2];
            srgbaTransformed[1] = -0.058496*srgba[0] +  0.979410*srgba[1] +  0.079086*srgba[2];
            srgbaTransformed[2] = -0.002346*srgba[0] +  0.403492*srgba[1] +  0.598854*srgba[2];
            break;
    
        case 8:
            srgbaTransformed[0] =  1.257728*srgba[0] + -0.139648*srgba[1] + -0.118081*srgba[2];
            srgbaTransformed[1] = -0.078003*srgba[0] +  0.975409*srgba[1] +  0.102594*srgba[2];
            srgbaTransformed[2] = -0.003316*srgba[0] +  0.501214*srgba[1] +  0.502102*srgba[2];
            break;

        case 9:
            srgbaTransformed[0] =  1.278864*srgba[0] + -0.125333*srgba[1] + -0.153531*srgba[2];
            srgbaTransformed[1] = -0.084748*srgba[0] +  0.957674*srgba[1] +  0.127074*srgba[2];
            srgbaTransformed[2] = -0.000989*srgba[0] +  0.601151*srgba[1] +  0.399838*srgba[2];
            break;
    
        case 10:
            srgbaTransformed[0] =  1.255528*srgba[0] + -0.076749*srgba[1] + -0.178779*srgba[2];
            srgbaTransformed[1] = -0.078411*srgba[0] +  0.930809*srgba[1] +  0.147602*srgba[2];
            srgbaTransformed[2] =  0.004733*srgba[0] +  0.691367*srgba[1] +  0.303900*srgba[2];
            break;
            
        default:
            srgbaTransformed[0] = 1*srgba[0] + 0*srgba[1] + 0*srgba[2];
            srgbaTransformed[1] = 0*srgba[0] + 1*srgba[1] + 0*srgba[2];
            srgbaTransformed[2] = 0*srgba[0] + 0*srgba[1] + 1*srgba[2];
            break;
    }
#endif
    srgbaTransformed[3] =                                                   1.0*srgba[3];
    return srgbaTransformed;
}

//----------------------------------
// Viénot 1999 - Protan
//----------------------------------

float3 applyProtanopiaVienot(
    float3 lms,
    float severity)
{
    float3 outLms = lms;

    outLms.x =
        (1.0 - severity) * lms.x +
        severity *
        (2.02344 * lms.y -
         2.52580 * lms.z);

    return outLms;
}

//----------------------------------
// Viénot 1999 - Deutan
//----------------------------------

float3 applyDeuteranopiaVienot(
    float3 lms,
    float severity)
{
    float3 outLms = lms;

    outLms.y =
        (1.0 - severity) * lms.y +
        severity *
        (0.49421 * lms.x +
         1.24827 * lms.z);

    return outLms;
}


//----------------------------------
// Viénot 1999 - Tritan
//----------------------------------

float3 applyTritanopiaVienot(
    float3 lms,
    float severity)
{
    float3 outLms = lms;

    outLms.z =
        (1.0 - severity) * lms.z +
        severity *
        (-0.01224 * lms.x +
          0.07203 * lms.y);

    return outLms;
}

//----------------------------------
// Brettel 1997 - Tritan
//----------------------------------

float3 applyTritanopiaBrettel(
    float3 lms,
    float severity)
{
    float3 outLms = lms;

    if ((lms.x * 0.34478 -
         lms.y * 0.65518) >= 0.0)
    {
        // Plane 1

        outLms.z =
            (1.0 - severity) * lms.z +
            severity *
            (-0.00257 * lms.x +
              0.05366 * lms.y);
    }
    else
    {
        // Plane 2

        outLms.z =
            (1.0 - severity) * lms.z +
            severity *
            (-0.06011 * lms.x +
              0.16299 * lms.y);
    }

    return outLms;
}


fragment float4 fragment_simulateDaltonism_protanope(VertexOut vert [[stage_in]],
                                                     texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 lms = lmsFromSRGBA(srgba);
    float3 lmsTransformed = applyProtanope(lms);
    float4 srgbaOut = sRGBAFromLms(lmsTransformed, 1.0);
    return srgbaOut;
}

fragment float4 fragment_simulateDaltonism_deuteranope(VertexOut vert [[stage_in]],
                                                       texture2d<float> screenTexture [[texture(0)]])
{
    
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 lms = lmsFromSRGBA(srgba);
    float3 lmsTransformed = applyDeuteranope(lms);
    float4 srgbaOut = sRGBAFromLms(lmsTransformed, 1.0);
    return srgbaOut;
}

fragment float4 fragment_simulateDaltonism_tritanope(VertexOut vert [[stage_in]],
                                                     texture2d<float> screenTexture [[texture(0)]])
{
    
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 lms = lmsFromSRGBA(srgba);
    float3 lmsTransformed = applyTritanope(lms);
    float4 srgbaOut = sRGBAFromLms(lmsTransformed, 1.0);
    return srgbaOut;
}

fragment float4 fragment_simulateDaltonism_protanomaly(VertexOut vert [[stage_in]],
                                                       texture2d<float> screenTexture [[texture(0)]],
                                                       constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaOut = applyProtanomalyRgb(srgba,uniforms.severity);
    
    /* simulate with Vienot
    float severity =
        clamp(
            uniforms.severity / 10.0,
            0.0,
            1.0);
    float3 lms = lmsFromSRGBA(srgba);
    float3 simulatedLms = applyProtanopiaVienot(lms, severity);
    float4 srgbaOut = sRGBAFromLms_no_clamp(simulatedLms, 1.0);
    */
    
    return srgbaOut;
}

fragment float4 fragment_simulateDaltonism_deuteranomaly(VertexOut vert [[stage_in]],
                                                         texture2d<float> screenTexture [[texture(0)]],
                                                         constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaOut = applyDeuteranomalyRgb(srgba,uniforms.severity);
    return srgbaOut;
}

fragment float4 fragment_simulateDaltonism_tritanomaly(VertexOut vert [[stage_in]],
                                                       texture2d<float> screenTexture [[texture(0)]],
                                                       constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaOut = applyTritanomalyRgb(srgba,uniforms.severity);
    return srgbaOut;
}

float4 daltonizeV1 (float4 srgba, float4 srgbaSimulated)
{
    float3 error = srgba.rgb - srgbaSimulated.rgb;
    
    int useOrgDaltonize = 1;
    
    float updatedR = 0;
    float updatedG = 0;
    float updatedB = 0;
    
    if (useOrgDaltonize == 1)
    {
        updatedR = srgba.r + 0.7*error.r;
        updatedG = srgba.g + 0.4*error.r + 1.0*error.g + 0.0*error.b;
        updatedB = srgba.b + 0.1*error.r + 0.0*error.g + 1.0*error.b;
    }
    else
    {
        updatedR = srgba.r + 1.0*error.r;
        updatedG = srgba.g + 1.0*error.g;
        updatedB = srgba.b + 1.0*error.b;
    }
    
    float4 srgbaOut = srgba;
    srgbaOut.r = clamp(updatedR, 0.0, 1.0);
    srgbaOut.g = clamp(updatedG, 0.0, 1.0);
    srgbaOut.b = clamp(updatedB, 0.0, 1.0);

    
    return srgbaOut;
}

fragment float4 fragment_daltonizeV1_protanope(VertexOut vert [[stage_in]],
                                               texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 lms = lmsFromSRGBA(srgba);
    float3 lmsSimulated = applyProtanope(lms);
    float4 srgbaSimulated = sRGBAFromLms(lmsSimulated, 1.0);
    float4 srgbaOut = daltonizeV1(srgba, srgbaSimulated);
    return srgbaOut;
}

fragment float4 fragment_daltonizeV1_deuteranope(VertexOut vert [[stage_in]],
                                                 texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 lms = lmsFromSRGBA(srgba);
    float3 lmsSimulated = applyDeuteranope(lms);
    float4 srgbaSimulated = sRGBAFromLms(lmsSimulated, 1.0);
    float4 srgbaOut = daltonizeV1(srgba, srgbaSimulated);
    return srgbaOut;
}

fragment float4 fragment_daltonizeV1_tritanope(VertexOut vert [[stage_in]],
                                               texture2d<float> screenTexture [[texture(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 lms = lmsFromSRGBA(srgba);
    float3 lmsSimulated = applyTritanope(lms);
    float4 srgbaSimulated = sRGBAFromLms(lmsSimulated, 1.0);
    float4 srgbaOut = daltonizeV1(srgba, srgbaSimulated);
    return srgbaOut;
}

fragment float4 fragment_daltonizeV1_protanomaly(VertexOut vert [[stage_in]],
                                                 texture2d<float> screenTexture [[texture(0)]],
                                                 constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaSimulated = applyProtanomalyRgb(srgba,uniforms.severity);
    float4 srgbaOut = daltonizeV1(srgba, srgbaSimulated);
    return srgbaOut;
}

fragment float4 fragment_daltonizeV1_deuteranomaly(VertexOut vert [[stage_in]],
                                                   texture2d<float> screenTexture [[texture(0)]],
                                                   constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaSimulated = applyDeuteranomalyRgb(srgba,uniforms.severity);
    float4 srgbaOut = daltonizeV1(srgba, srgbaSimulated);
    return srgbaOut;
}

fragment float4 fragment_daltonizeV1_tritanomaly(VertexOut vert [[stage_in]],
                                                 texture2d<float> screenTexture [[texture(0)]],
                                                 constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float4 srgbaSimulated = applyTritanomalyRgb(srgba,uniforms.severity);
    float4 srgbaOut = daltonizeV1(srgba, srgbaSimulated);
    return srgbaOut;
}

float luminance(float4 srgba)
{
    return
        0.2126 * srgba.r +
        0.7152 * srgba.g +
        0.0722 * srgba.b;
}

// DCK16L (old version)
// srgba is original color value of the pixel
// simulated is a simulated CVD value of the pixel (you can use different CDV simulations)
// parameters dck16RG, dck16RB and dck16GB are vital to control how strong the RG/GB/RB differences are applied.
// the dck16RG, dck16RB and dck16GB parameters are needed to adapped individually for the severity level by the user.
// finding appropriate parameters can be very tricky and is no easy taks and the reason DCK17L was created.
// the CDV correction in DCK16L is determined independently by CDV simulation and the RG/GB/RB differences.
// dck17PreserveLuma can be between 0.0 and 1.0 and defines the level of lumina preservation.
// it is recommended to be at 1.0 so that the CDV correction does not over-saturate the brightness.
//
float4 dck16l(
             float4 srgba,
             float4 simulated,
             float dckRG,
             float dckRB,
             float dckGB,
             float dckPreserveLuma)
{
    //----------------------------------
    // 1) CVD Simulation
    //----------------------------------
    
    // call parameter simulated contains the values changed by used CVD simulation, while srgba is original value
    
    //----------------------------------
    // 2) DC1 (daltonizeV1)
    //----------------------------------

    float4 dc =
        daltonizeV1(
            srgba,
            simulated);

    //----------------------------------
    // 3) K16 correction
    //----------------------------------

    float rg =
        dc.r - dc.g;

    float rb =
        dc.r - dc.b;

    float gb =
        dc.g - dc.b;

    dc.r +=
        rg * dckRG +
        rb * dckRB;

    dc.g +=
       -rg * dckRG +
        gb * dckGB;

    dc.b +=
       -rb * dckRB -
        gb * dckGB;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);
    
    //----------------------------------
    // 4) L (luminance preserve)
    //----------------------------------

    float yOriginal =
        luminance(
                  srgba);

    float yCorrected =
        luminance(
            dc);

    float deltaY =
        yCorrected -
        yOriginal;

    dc.rgb -=
        float3(deltaY) *
        dckPreserveLuma;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);

    return dc;
}


// DCK17L
// srgba is original color value of the pixel
// simulated is a simulated CVD value of the pixel (you can use different CDV simulations)
// only the RG/GB/RB differences of srgba and simulated determine the CDV correction in DCK17L.
// dck17PreserveLuma can be between 0.0 and 1.0 and defines the level of lumina preservation.
// it is recommended to be at 1.0 so that the CDV correction does not over-saturate the brightness.
//
float4 dck17l(
             float4 srgba,
             float4 simulated,
             float dckRG,
             float dckRB,
             float dckGB,
             float dckPreserveLuma)
{
    //----------------------------------
    // 1) CVD Simulation
    //----------------------------------
    
    // call parameter simulated contains the values changed by used CVD simulation, while srgba is original value

    //----------------------------------
    // 2) Original channel differences
    //----------------------------------

    float rgOriginal =
        srgba.r - srgba.g;

    float rbOriginal =
        srgba.r - srgba.b;

    float gbOriginal =
        srgba.g - srgba.b;

    //----------------------------------
    // 3) Simulated channel differences
    //----------------------------------

    float rgSimulated =
        simulated.r - simulated.g;

    float rbSimulated =
        simulated.r - simulated.b;

    float gbSimulated =
        simulated.g - simulated.b;

    //----------------------------------
    // 4) Information loss
    //----------------------------------

    float rgError =
        rgOriginal - rgSimulated;

    float rbError =
        rbOriginal - rbSimulated;

    float gbError =
        gbOriginal - gbSimulated;

    //----------------------------------
    // 5) DCK17 correction
    //----------------------------------

    float4 dc =
        srgba;

    dc.r +=
        rgError * dckRG +
        rbError * dckRB;

    dc.g +=
       -rgError * dckRG +
        gbError * dckGB;

    dc.b +=
       -rbError * dckRB -
        gbError * dckGB;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);

    //----------------------------------
    // 6) Luminance preserve
    //----------------------------------

    float yOriginal =
        luminance(
            srgba);

    float yCorrected =
        luminance(
            dc);

    float deltaY =
        yCorrected -
        yOriginal;

    dc.rgb -=
        float3(deltaY) *
        dckPreserveLuma;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);

    return dc;
}

// DCK18L (DCK17L with soft compression)
// srgba is original color value of the pixel
// simulated is a simulated CVD value of the pixel (you can use different CDV simulations)
// only the RG/GB/RB differences of srgba and simulated determine the CDV correction in DCK18L.
// dck1PreserveLuma can be between 0.0 and 1.0 and defines the level of lumina preservation.
// it is recommended to be at 1.0 so that the CDV correction does not over-saturate the brightness.
float4 dck18l(
             float4 srgba,
             float4 simulated,
             float dckRG,
             float dckRB,
             float dckGB,
             float dckSoftCompress,
             float dckPreserveLuma)
{
    //----------------------------------
    // 1) Original channel differences
    //----------------------------------

    float rgOriginal =
        srgba.r - srgba.g;

    float rbOriginal =
        srgba.r - srgba.b;

    float gbOriginal =
        srgba.g - srgba.b;

    //----------------------------------
    // 2) Simulated channel differences
    //----------------------------------

    float rgSimulated =
        simulated.r - simulated.g;

    float rbSimulated =
        simulated.r - simulated.b;

    float gbSimulated =
        simulated.g - simulated.b;

    //----------------------------------
    // 3) Information loss
    //----------------------------------

    float rgError =
        rgOriginal - rgSimulated;

    float rbError =
        rbOriginal - rbSimulated;

    float gbError =
        gbOriginal - gbSimulated;

    //----------------------------------
    // 4) DCK17 correction
    //----------------------------------

    float deltaR =
        rgError * dckRG +
        rbError * dckRB;

    float deltaG =
       -rgError * dckRG +
        gbError * dckGB;

    float deltaB =
       -rbError * dckRB -
        gbError * dckGB;

    //----------------------------------
    // 5) Soft Compression
    //----------------------------------

    float distR =
        (deltaR >= 0.0)
        ? max(0.0, 1.0 - srgba.r)
        : max(0.0, srgba.r);

    float distG =
        (deltaG >= 0.0)
        ? max(0.0, 1.0 - srgba.g)
        : max(0.0, srgba.g);
    
    float distB =
        (deltaB >= 0.0)
        ? max(0.0, 1.0 - srgba.b)
        : max(0.0, srgba.b);
    
    float exponent =
        0.5 * dckSoftCompress;
    
    float gainR =
        (dckSoftCompress <= 0.0)
        ? 1.0
        : pow(distR, exponent);
    
    float gainG =
        (dckSoftCompress <= 0.0)
        ? 1.0
        : pow(distG, exponent);
    
    float gainB =
        (dckSoftCompress <= 0.0)
        ? 1.0
        : pow(distB, exponent);

    //----------------------------------
    // 6) Apply correction
    //----------------------------------

    float4 dc =
        srgba;

    dc.r +=
        deltaR * gainR;

    dc.g +=
        deltaG * gainG;

    dc.b +=
        deltaB * gainB;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);

    //----------------------------------
    // 7) Luminance preserve
    //----------------------------------

    float yOriginal =
        luminance(
            srgba);

    float yCorrected =
        luminance(
            dc);

    float deltaY =
        yCorrected -
        yOriginal;

    dc.rgb -=
        float3(deltaY) *
        dckPreserveLuma;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);

    return dc;
}

// DCK19L (DCK18L with adaptive luma preservation)
// srgba is original color value of the pixel
// simulated is a simulated CVD value of the pixel (you can use different CDV simulations)
// only the RG/GB/RB differences of srgba and simulated determine the CDV correction in DCK18L.
// dckPreserveLuma can be between 0.0 and 1.0 and defines the level of Adaptive Luminance Preserve=1.0. it is recommended to be at 1.0 so that the CDV correction does not over-saturate the brightness. dckSoftCompress is no longer needed and can be 0 if dckPreserveLuma is used at 1.0
// Adaptive Luminance Preserve let correction values that would be clipped to stong over 255 of color chanel and paint those clipped areas in pink/magenta colors.
float4 dck19l(
             float4 srgba,
             float4 simulated,
             float dckRG,
             float dckRB,
             float dckGB,
             float dckSoftCompress,
             float dckPreserveLuma)
{
    //----------------------------------
    // 1) Original channel differences
    //----------------------------------

    float rgOriginal =
        srgba.r - srgba.g;

    float rbOriginal =
        srgba.r - srgba.b;

    float gbOriginal =
        srgba.g - srgba.b;

    //----------------------------------
    // 2) Simulated channel differences
    //----------------------------------

    float rgSimulated =
        simulated.r - simulated.g;

    float rbSimulated =
        simulated.r - simulated.b;

    float gbSimulated =
        simulated.g - simulated.b;

    //----------------------------------
    // 3) Information loss
    //----------------------------------

    float rgError =
        rgOriginal - rgSimulated;

    float rbError =
        rbOriginal - rbSimulated;

    float gbError =
        gbOriginal - gbSimulated;

    //----------------------------------
    // 4) DCK17 correction
    //----------------------------------

    float deltaR =
        rgError * dckRG +
        rbError * dckRB;

    float deltaG =
       -rgError * dckRG +
        gbError * dckGB;

    float deltaB =
       -rbError * dckRB -
        gbError * dckGB;

    //----------------------------------
    // 5) Soft Compression
    //----------------------------------

    float distR =
        (deltaR >= 0.0)
        ? max(0.0, 1.0 - srgba.r)
        : max(0.0, srgba.r);

    float distG =
        (deltaG >= 0.0)
        ? max(0.0, 1.0 - srgba.g)
        : max(0.0, srgba.g);
    
    float distB =
        (deltaB >= 0.0)
        ? max(0.0, 1.0 - srgba.b)
        : max(0.0, srgba.b);
    
    float exponent =
        0.5 * dckSoftCompress;
    
    float gainR =
        (dckSoftCompress <= 0.0)
        ? 1.0
        : pow(distR, exponent);
    
    float gainG =
        (dckSoftCompress <= 0.0)
        ? 1.0
        : pow(distG, exponent);
    
    float gainB =
        (dckSoftCompress <= 0.0)
        ? 1.0
        : pow(distB, exponent);

    //----------------------------------
    // 6) Apply correction
    //----------------------------------

    float4 dc =
        srgba;

    dc.r +=
        deltaR * gainR;

    dc.g +=
        deltaG * gainG;

    dc.b +=
        deltaB * gainB;

    dc.rgb =
        clamp(
            dc.rgb,
            0.0,
            1.0);

    //----------------------------------
    // 7) Adaptive Luminance Preserve
    //----------------------------------

    float yOriginal =
        luminance(
            srgba);

    float yCorrected =
        luminance(
            dc);

    float deltaY =
        yCorrected -
        yOriginal;

    //----------------------------------
    // Visibility estimate
    //----------------------------------
    
    float visibility =
        length(
            float3(
                rgError,
                rbError,
                gbError));
    
    visibility /= 1.7320508; // normalization bc sqrt(3) = 1.7320508

    visibility =
        clamp(
            visibility,
            0.0,
            1.0);

    //----------------------------------
    // Adaptive LP
    //----------------------------------

    float lp =
        dckPreserveLuma *
        (1.0 + visibility);

    //----------------------------------
    // Apply
    //----------------------------------

    dc.rgb -=
        float3(deltaY) *
        lp;

    return dc;
}

fragment float4 fragment_DCKL_protanomaly(
    VertexOut vert [[stage_in]],
    texture2d<float> screenTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]])
{
    float4 srgba =
        screenTexture.sample(
            defaultSampler,
            vert.texCoords);
    
    float4 simulated;
    if (uniforms.dcklSimu==0)
    {
        //----------------------------------
        // Machado CVD simulation for Protanomaly
        //----------------------------------

        int sev =
            clamp(
                int(floor(uniforms.dcklSeverity + 0.5)),
                0,
                10);

        simulated =
            applyProtanomalyRgb(
                srgba,
                sev);
    }
    else if (uniforms.dcklSimu==1)
    {
        //----------------------------------
        // Vienot CVD simulation for Protanomaly
        //----------------------------------

        float severity =
            clamp(
                uniforms.dcklSeverity / 10.0,
                0.0,
                1.0);
        
        float3 lms = lmsFromSRGBA(srgba);
        float3 simulatedLms = applyProtanopiaVienot(lms, severity);
        simulated = sRGBAFromLms_no_clamp(simulatedLms, 1.0);
    }
    else
    {
        simulated = srgba;
    }
    
#if defined(USE_DCK17L)
    // DCK17L
    float4 simuResult = dck17l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklPreserveLuma);
#elif defined(USE_DCK18L)
    float4 simuResult = dck18l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklSoftCompress,
            uniforms.dcklPreserveLuma);
#elif defined(USE_DCK19L)
    float4 simuResult = dck19l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklSoftCompress,
            uniforms.dcklPreserveLuma);
#else
    // DCK16L
    float4 simuResult = dck16l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklPreserveLuma);
#endif
    
    return simuResult;
}

fragment float4 fragment_DCKL_deuteranomaly(
    VertexOut vert [[stage_in]],
    texture2d<float> screenTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]])
{
    float4 srgba =
        screenTexture.sample(
            defaultSampler,
            vert.texCoords);
    
    float4 simulated;
    if (uniforms.dcklSimu==0)
    {
        //----------------------------------
        // Machado CVD simulation for Deuteranomaly
        //----------------------------------

        int sev =
            clamp(
                int(floor(uniforms.dcklSeverity + 0.5)),
                0,
                10);

        simulated =
            applyDeuteranomalyRgb(
                srgba,
                sev);
    }
    else if (uniforms.dcklSimu==1)
    {
        //----------------------------------
        // Vienot CVD simulation for Deuteranomaly
        //----------------------------------

        float severity =
            clamp(
                uniforms.dcklSeverity / 10.0,
                0.0,
                1.0);
        
        float3 lms = lmsFromSRGBA(srgba);
        float3 simulatedLms = applyDeuteranopiaVienot(lms, severity);
        simulated = sRGBAFromLms_no_clamp(simulatedLms, 1.0);
    }
    else
    {
        simulated = srgba;
    }
    
#if defined(USE_DCK17L)
    // DCK17L
    float4 simuResult = dck17l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklPreserveLuma);
#elif defined(USE_DCK18L)
    float4 simuResult = dck18l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklSoftCompress,
            uniforms.dcklPreserveLuma);
#elif defined(USE_DCK19L)
    float4 simuResult = dck19l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklSoftCompress,
            uniforms.dcklPreserveLuma);
#else
    // DCK16L
    float4 simuResult = dck16l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklPreserveLuma);
#endif
    return simuResult;
}

fragment float4 fragment_DCKL_tritanomaly(
    VertexOut vert [[stage_in]],
    texture2d<float> screenTexture [[texture(0)]],
    constant Uniforms& uniforms [[buffer(0)]])
{
    float4 srgba =
        screenTexture.sample(
            defaultSampler,
            vert.texCoords);
    
    float4 simulated;
    if (uniforms.dcklSimu==0)
    {
        //----------------------------------
        // Machado CVD simulation for Tritanomaly
        //----------------------------------

        int sev =
            clamp(
                int(floor(uniforms.dcklSeverity + 0.5)),
                0,
                10);

        simulated =
            applyTritanomalyRgb(
                srgba,
                sev);
    }
    else if (uniforms.dcklSimu==1)
    {
        //----------------------------------
        // Brettel CVD simulation for Tritanomaly
        //----------------------------------

        float severity =
            clamp(
                uniforms.dcklSeverity / 10.0,
                0.0,
                1.0);
        
        float3 lms = lmsFromSRGBA(srgba);
        float3 simulatedLms = applyTritanopiaBrettel(lms, severity);
        // WARNING: Viénot is not good for tritanopia, we need to switch to Brettel.
        //float3 simulatedLms = applyTritanopiaVienot(lms, severity);
        simulated = sRGBAFromLms_no_clamp(simulatedLms, 1.0);
    }
    else
    {
        simulated = srgba;
    }
#if defined(USE_DCK17L)
    // DCK17L
    float4 simuResult = dck17l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklPreserveLuma);
#elif defined(USE_DCK18L)
    float4 simuResult = dck18l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklSoftCompress,
            uniforms.dcklPreserveLuma);
#elif defined(USE_DCK19L)
    float4 simuResult = dck19l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklSoftCompress,
            uniforms.dcklPreserveLuma);
#else
    // DCK16L
    float4 simuResult = dck16l(
            srgba,
            simulated,
            uniforms.dcklRG,
            uniforms.dcklRB,
            uniforms.dcklGB,
            uniforms.dcklPreserveLuma);
#endif
    return simuResult;
}


bool colorsAreCompatibleWithAA(float r0, float g0, float r1, float g1)
{
    // FIXME: document this. This comes from some python experiments.
    // If the true color is c, then the final antialised color will be a blend
    // with the background. Assuming the background is white, we get a linear
    // constraint between the components. This checks is the constraints are
    // within range.
    float rg0 = (255.0-r0)/(255.0-g0);
    float rg1 = (255.0-r1)/(255.0-g1);
    float errRg0 = ((256.0-r0)/(255.0-g0)) - ((255.0-r0)/(256.0-g0));
    float errRg1 = ((256.0-r1)/(255.0-g1)) - ((255.0-r1)/(256.0-g1));
    float deltaRg = abs(rg0-rg1);
    bool cantTell = (g1 > 220);
    bool colorAreCompatible = (deltaRg < 6.0*(errRg0+errRg1));
    bool compatible = colorAreCompatible || cantTell;
    return compatible;
}

bool canMakeSignificantComparisonBetweenAAColors (float r0, float g0, float r1, float g1)
{
    // all the colors look similar when strongly blended with a white background.
    return (g1 < 200.0);
}

fragment float4 fragment_highlightSameColorWithAntialising(VertexOut vert [[stage_in]],
                                                           texture2d<float> screenTexture [[texture(0)]],
                                                           constant Uniforms &uniforms [[buffer(0)]])
{
    // FIXME: document this.
    float4 srgbaToHighlight = uniforms.srgbaUnderCursor;
    float3 yCbCrToHightlight = yCbCrFromSRGBA(srgbaToHighlight);
    float r0 = 255.0*srgbaToHighlight.r;
    float g0 = 255.0*srgbaToHighlight.g;
    float b0 = 255.0*srgbaToHighlight.b;
    
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    float3 yCbCr = yCbCrFromSRGBA(srgba);
    float r1 = 255.0*srgba.r;
    float g1 = 255.0*srgba.g;
    float b1 = 255.0*srgba.b;
    
    // NEXT IDEA: local neighborhood. Accept pixel if ok similariy if at least one neighbor with very good similarity. Nearest pixel sampling.
    
    // Check if all the channels satisfy the linear constraints of a single true color
    // blended with a white background due to antialiasing.
    bool compatibleColor = true;
    compatibleColor &= colorsAreCompatibleWithAA(r0,g0,r1,g1);
    compatibleColor &= colorsAreCompatibleWithAA(g0,r0,g1,r1);
    compatibleColor &= colorsAreCompatibleWithAA(r0,b0,r1,b1);
    compatibleColor &= colorsAreCompatibleWithAA(b0,r0,b1,r1);
    compatibleColor &= colorsAreCompatibleWithAA(g0,b0,g1,b1);
    compatibleColor &= colorsAreCompatibleWithAA(b0,g0,b1,g1);
    
    int numSignificant = (canMakeSignificantComparisonBetweenAAColors(r0,g0,r1,g1)
                          + canMakeSignificantComparisonBetweenAAColors(g0,r0,g1,r1)
                          + canMakeSignificantComparisonBetweenAAColors(r0,b0,r1,b1)
                          + canMakeSignificantComparisonBetweenAAColors(b0,r0,b1,r1)
                          + canMakeSignificantComparisonBetweenAAColors(g0,b0,g1,b1)
                          + canMakeSignificantComparisonBetweenAAColors(b0,g0,b1,g1));
                          
    bool isSignificantTest = (numSignificant>=1);
    
    bool isSameColor = isSignificantTest && compatibleColor;

    float finalWeight = select (0.0, 1.0, isSameColor); // 1.0 if isSameColor
    
    // Apply time-based weighting
    float t = uniforms.frameCount;
    float timeWeight = sin(t / 1.0)*0.5 + 0.5; // between 0 and 1
    
    finalWeight = (finalWeight*timeWeight + 1.0)/2.0; // between 0 and 1, min 0.5
    
    // Don't highlight gray stuff.
    bool isGray = length(yCbCr.yz) < 0.01;
    finalWeight = select (finalWeight, 1.0, isGray);
    
    float3 weightedSRGB = srgba.rgb * finalWeight;
    
    bool shouldHighlight = length(yCbCrToHightlight.yz) > 0.01;
    float3 finalSRGB = select (srgba.rgb, weightedSRGB, shouldHighlight);
    return float4(finalSRGB, 1.0);
}

fragment float4 fragment_highlightSameColor(VertexOut vert [[stage_in]],
                                            texture2d<float> screenTexture [[texture(0)]],
                                            constant Uniforms &uniforms [[buffer(0)]])
{
    float4 srgbaToHighlight = uniforms.srgbaUnderCursor;
    float4 srgba = screenTexture.sample(defaultSampler, vert.texCoords);
    
    // Compare the current color with the reference one.
    bool isSame = length(srgbaToHighlight.rgb - srgba.rgb) < 0.01;
    
    // FIXME: document this better.
    
    float3 yCbCr = yCbCrFromSRGBA(srgba);
    yCbCr.yz = select (float2(0,0), yCbCr.yz, isSame);
    
    float t = uniforms.frameCount;
    float timeWeight = sin(t / 2.0)*0.5 + 0.5; // between 0 and 1
    timeWeight = select (timeWeight*0.5, -timeWeight*0.8, yCbCr.x > 0.86);
    float timeWeightedIntensity = yCbCr.x + timeWeight;
    yCbCr.x = select (yCbCr.x, timeWeightedIntensity, isSame);

    float3 yCbCrToHightlight = yCbCrFromSRGBA(srgbaToHighlight);
    bool shouldHighlight = length(yCbCrToHightlight.yz) > 0.01;
    
    float3 transformedSRGB = sRGBAfromYCbCr(yCbCr, 1.0).rgb;
    
    float3 finalSRGB = select (srgba.rgb, transformedSRGB, shouldHighlight);
    return float4(finalSRGB, 1.0);
}
