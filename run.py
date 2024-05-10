import time
import datetime
import os
import pytesseract
import cv2
import numpy as np
from PIL import Image
from Quartz import (
    CGWindowListCopyWindowInfo,
    kCGWindowListOptionOnScreenOnly,
    kCGNullWindowID,
    CoreGraphics as CG
)
from openai import OpenAI

client = OpenAI()


def find_terminal_window():
    windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
    for window in windows:
        if window['kCGWindowOwnerName'] == 'Terminal' and 'kCGWindowName' in window:
            return window
    return None

def capture_specific_window(window_id):
    # Define the region to capture based on the window ID
    region = CG.CGRectNull  # Use CGRectNull to specify capture by window ID
    image = CG.CGWindowListCreateImage(region, CG.kCGWindowListOptionIncludingWindow, window_id, CG.kCGWindowImageBoundsIgnoreFraming)

    if image:
        width = CG.CGImageGetWidth(image)
        height = CG.CGImageGetHeight(image)
        bytes_per_row = CG.CGImageGetBytesPerRow(image)
        pixel_data = CG.CGDataProviderCopyData(CG.CGImageGetDataProvider(image))
        image = Image.frombytes("RGBA", (width, height), pixel_data, "raw", "BGRA", bytes_per_row, 1)
        return image
    else:
        return None



def extract_highlighted_text(image_path):
    # Convert the image to RGB (OpenCV uses BGR by default)
    #image = np.array(pil_image)
    image = cv2.imread(image_path)
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Convert the image to HSV for color filtering
    image_hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

    # Define the range of blue color in HSV
    # Adjust these values based on the shade of the highlighter and image theme
    lower_blue = np.array([100, 50, 50])
    upper_blue = np.array([140, 255, 255])

    # Threshold the HSV image to get only blue colors
    mask = cv2.inRange(image_hsv, lower_blue, upper_blue)

    # Bitwise-AND mask and original image to isolate highlighted areas
    highlighted = cv2.bitwise_and(image_rgb, image_rgb, mask=mask)

    # Convert highlighted image to grayscale
    gray_image = cv2.cvtColor(highlighted, cv2.COLOR_RGB2GRAY)

    # Binarize the image for better OCR results
    _, binary_image = cv2.threshold(gray_image, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # Use pytesseract to do OCR on the preprocessed image
    text = pytesseract.image_to_string(binary_image, config='--psm 6')

    if text:
        print(f"looking at {text.strip()}")
    return text.strip()

def openai_describe(text, highlight=''):
    openai_call = None

    if highlight:
        highlight = f'the words "{highlight}"'
    else:
        highlight = "the last command or line"
    
    prompt=f"Analyze the following terminal sesson (paying attention to {highlight}):\n{text}\n\nWhat am I trying to do, and what would be a better command if there is an error?"
    response = client.chat.completions.create(
    model="gpt-3.5-turbo",
    messages=[
        {"role": "system", "content": "You are a helpful, knowledgable and concise sysadmin assistant.  When useful, you return one shell command at a time, bracketed by three backticks (```)"},
        {"role": "user", "content": "I'm using terminal on MacOS 14.1.2. I'd like to share my output with you and get your advice."},
        {"role": "assistant", "content": "Sure! Let me see it."},
        {"role": "user", "content": prompt}
      ],                                         
    max_tokens=100)

    return response.choices[0].message.content
    

def save_image(image, path):
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S%f")
    filename = f"{path}/screenshot_{timestamp}.png"
    image.save(filename)
    return filename

def capture_terminal_continuously(interval=0.05, path='./tmp/screenshots', txtpath = './tmp/ocr_output.txt'):
    if not os.path.exists(path):
        os.makedirs(path)

    try:
        text = ''
        old_text = ''
        highlight = ''
        old_highlight = ''

        while True:
            terminal_window = find_terminal_window()
            if terminal_window:
                window_id = terminal_window['kCGWindowNumber']
                img = capture_specific_window(window_id)
                if img:
                    width, height = img.size
                    area = (0, 60, width, height) #HACK to cut off the navbar.
                    cropped_img = img.crop(area)
                    filename = save_image(cropped_img, path)
                    highlight = extract_highlighted_text(filename)
                    text = image_to_text(cropped_img, txtpath)

                    if (text[-10:] == old_text[-10:]) and (highlight == old_highlight):
                        pass #not enough have changed
                        print("...waiting...")
                    else:   
                        intent = openai_describe(text, highlight)
                        os.system('clear') 
                        print(intent)
                    old_text = text
                    old_highlight = highlight
            time.sleep(interval)  # Sleep for 50 milliseconds
    except KeyboardInterrupt:
        print("Stopped by user.")


def image_to_text(img, output_path):
    # Use Tesseract to do OCR on the image
    print("...looking...")
    text = pytesseract.image_to_string(img)

    # Save the text to a file
    with open(output_path, 'w') as file:
        file.write(text)

    return text

# Run the continuous capture
capture_terminal_continuously()