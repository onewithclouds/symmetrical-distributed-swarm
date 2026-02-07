import onnx
from onnxruntime.quantization import quantize_dynamic, QuantType

# Paths
input_model_path = "yolox_l.onnx"
output_model_path = "yolox_l_int8.onnx"

print(f"🧠 Quantizing {input_model_path} to Int8...")

quantize_dynamic(
    model_input=input_model_path,
    model_output=output_model_path,
    weight_type=QuantType.QUInt8  # Quantize weights to Unsigned Int8
)

print(f"✅ Success! Brain optimized at {output_model_path}")