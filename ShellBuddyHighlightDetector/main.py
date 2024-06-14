from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import base64
import cv2
import numpy as np
import os
from image_processor import ImageProcessor, highlight_colors

app = FastAPI()

class ImagePayload(BaseModel):
    image: str

@app.post("/upload-image/")
async def upload_image(payload: ImagePayload):
    try:
        # Decode the Base64 image
        image_data = base64.b64decode(payload.image)
        
        # Convert the binary data to a numpy array
        np_arr = np.frombuffer(image_data, np.uint8)
        
        # Decode the numpy array to an image
        image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise ValueError("Could not decode image")

        # Save the received image
        #input_image_path = "received_image.png"
        #cv2.imwrite(input_image_path, image)

        # Process the image using the ImageProcessor class
        processor = ImageProcessor(image, highlight_colors)
        cropped_image, is_highlight_present = processor.process_image()
        
        if cropped_image is None:
            raise ValueError("No highlighted regions found")

        # Save the cropped image
        #output_image_path = "cropped_image.png"
        #cv2.imwrite(output_image_path, cropped_image)

        # Encode the cropped image to Base64
        _, buffer = cv2.imencode('.png', cropped_image)
        cropped_image_base64 = base64.b64encode(buffer).decode('utf-8')

        return {
            "message": "Image processed successfully",
            "cropped_image": cropped_image_base64,
            "is_highlight_present": is_highlight_present
        }
    except Exception as e:
        return {
            "message": f"Invalid image data: {e}",
            "is_highlight_present": False
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

def encode_image(image_path):
    """Encode the image at the given path to Base64."""
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')
