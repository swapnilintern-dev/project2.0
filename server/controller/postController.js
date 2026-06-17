import sharp from "sharp";
import cloudinary from "../utils/cloudinary.js";
import Product from "../model/productModel.js";

const addnewProduct = async (req, res) => {
  try {
    const {
      title,
      description,
      price,
      category,
    } = req.body;

    console.log("Text Data:", req.body);

    const image = req.file;

    console.log("Image:", image);

    // Validation
    if (!image) {
      return res.status(400).json({
        success: false,
        message: "Image is required",
      });
    }

    if (!title) {
      return res.status(400).json({
        success: false,
        message: "Title is required",
      });
    }

    if (!price) {
      return res.status(400).json({
        success: false,
        message: "Price is required",
      });
    }

    // Optimize Image
    const optimizedImgBuffer = await sharp(image.buffer)
      .resize({
        width: 800,
        height: 800,
        fit: "inside",
      })
      .jpeg({ quality: 80 })
      .toBuffer();

    // Buffer -> Data URI
    const fileUri = `data:image/jpeg;base64,${optimizedImgBuffer.toString(
      "base64"
    )}`;

    // Upload to Cloudinary
    const cloudResponse = await cloudinary.uploader.upload(fileUri, {
      folder: "products",
    });

    console.log("Cloudinary Response:", cloudResponse);

    // Save Product
    const product = await Product.create({
      title,
      description,
      price,
      category,
      image: [
        {
          url: cloudResponse.secure_url,
          publicId: cloudResponse.public_id,
        },
      ],
    });

    return res.status(201).json({
      success: true,
      message: "Product added successfully",
      product,
    });
  } catch (error) {
    console.error("Add Product Error:", error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

export default addnewProduct;