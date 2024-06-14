import cv2
import numpy as np
from sklearn.cluster import KMeans

highlight_colors = {
    "dark_background": [
        {"name": "color1", "rgb": (63, 99, 139), "hex": "#3F638B"},
        {"name": "color2", "rgb": (112, 87, 113), "hex": "#705771"},
        {"name": "color3", "rgb": (137, 87, 110), "hex": "#89576E"},
        {"name": "color4", "rgb": (139, 87, 89), "hex": "#8B5759"},
        {"name": "color5", "rgb": (137, 102, 71), "hex": "#896647"},
        {"name": "color6", "rgb": (139, 122, 63), "hex": "#8B7A3F"},
        {"name": "color7", "rgb": (92, 118, 84), "hex": "#5C7654"}
    ],
    "white_background": [
        {"name": "color1", "rgb": (179, 215, 255), "hex": "#B3D7FF"},
        {"name": "color2", "rgb": (223, 197, 224), "hex": "#DFC5E0"},
        {"name": "color3", "rgb": (253, 203, 226), "hex": "#FDCBE2"},
        {"name": "color4", "rgb": (246, 196, 197), "hex": "#F6C4C5"},
        {"name": "color5", "rgb": (253, 218, 187), "hex": "#FDDABB"},
        {"name": "color6", "rgb": (255, 238, 190), "hex": "#FFEEBE"},
        {"name": "color7", "rgb": (208, 234, 200), "hex": "#D0EAC8"}
    ]
}

class ImageProcessor:
    def __init__(self, image, highlight_colors):
        self.image = image
        self.highlight_colors = highlight_colors
        self.cluster_centers = None

    def is_black_or_white(self, color, threshold=10):
        if all(color <= threshold) or all(color >= (255 - threshold)):
            return True
        return False

    def extract_color_spectrum(self, num_colors=10):
        image = cv2.cvtColor(self.image, cv2.COLOR_BGR2RGB)
        pixels = image.reshape(-1, 3)

        kmeans = KMeans(n_clusters=num_colors)
        kmeans.fit(pixels)
        labels = kmeans.labels_
        cluster_centers = kmeans.cluster_centers_

        label_counts = np.bincount(labels)
        sorted_idx = np.argsort(label_counts)[::-1]
        self.cluster_centers = cluster_centers[sorted_idx]
        label_counts = label_counts[sorted_idx]

        filtered_centers = []
        for i, color in enumerate(self.cluster_centers):
            if not self.is_black_or_white(color):
                filtered_centers.append(color)

        self.cluster_centers = np.array(filtered_centers)

    def detect_highlight_colors(self, tolerance=5):
        detected_colors = []
        for color_set in self.highlight_colors.values():
            for highlight in color_set:
                highlight_rgb = np.array(highlight["rgb"])
                for center in self.cluster_centers:
                    if np.all(np.abs(center - highlight_rgb) <= tolerance):
                        detected_colors.append(highlight)
                        break
        return detected_colors

    def create_mask(self, color, tolerance=5):
        hsv_image = cv2.cvtColor(self.image, cv2.COLOR_BGR2HSV)
        color_hsv = cv2.cvtColor(np.uint8([[color]]), cv2.COLOR_RGB2HSV)[0][0]

        lower_bound = np.array([color_hsv[0] - tolerance, color_hsv[1] - tolerance, color_hsv[2] - tolerance])
        upper_bound = np.array([color_hsv[0] + tolerance, color_hsv[1] + tolerance, color_hsv[2] + tolerance])

        mask = cv2.inRange(hsv_image, lower_bound, upper_bound)
        result = cv2.bitwise_and(self.image, self.image, mask=mask)
        result[mask == 0] = [0, 0, 0]

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        largest_contour = max(contours, key=cv2.contourArea) if contours else None

        return mask, result, largest_contour

    def process_image(self, tolerance=20):
        self.extract_color_spectrum()
        detected_colors = self.detect_highlight_colors(tolerance)
        for color in detected_colors:
            mask, result, largest_contour = self.create_mask(color['rgb'], tolerance)
            if largest_contour is not None:
                return self.crop_image(largest_contour), True
        return None, False

    def crop_image(self, contour):
        _, y, _, h = cv2.boundingRect(contour)
        return self.image[y:y+h, :]

