import Vendor from "../model/userModel.js";
import cloudinary from "../utils/cloudinary.js";
import getDatauri from "../utils/datauri.js";
import sharp from "sharp";

export const registerVendor = async (req, res) => {
  try {
    const {
      vendor_type,
      shop_type,
      store_name,
      contact_person_name,
      mobile_no,
      email,
      full_address,
      city,
      state,
      pin_code,
      gst_status,
      drug_lic_no,
      drug_lic_ex_date,
      password,
    } = req.body;

    const gst_pdf = req.files?.gst_pdf?.[0];
    const store_pic = req.files?.store_pic?.[0];
    const drug_lic_copy = req.files?.drug_lic_copy?.[0];

    // Basic Validation
    if (!store_name || !mobile_no || !email ) {
      return res.status(400).json({
        success: false,
        message: "Required fields are missing",
      });
    }

    if (!store_pic) {
      return res.status(400).json({
        success: false,
        message: "Store image is required",
      });
    }

    let gstUpload = null;
    let drugUpload = null;

    // Store Image Upload
    const optimizedImage = await sharp(store_pic.buffer)
      .resize({
        width: 800,
        height: 800,
        fit: "inside",
      })
      .jpeg({ quality: 80 })
      .toBuffer();

    const imageUri = `data:image/jpeg;base64,${optimizedImage.toString(
      "base64"
    )}`;

    const storeUpload = await cloudinary.uploader.upload(imageUri, {
      folder: "vendors/store-images",
    });

    // GST PDF Upload
    if (gst_pdf) {
      const gstUri = getDatauri(gst_pdf);

      gstUpload = await cloudinary.uploader.upload(gstUri, {
        folder: "vendors/gst",
        resource_type: "raw",
      });
    }

    // Drug License PDF Upload
    if (drug_lic_copy) {
      const drugUri = getDatauri(drug_lic_copy);

      drugUpload = await cloudinary.uploader.upload(drugUri, {
        folder: "vendors/drug-license",
        resource_type: "raw",
      });
    }

    const vendor = await Vendor.create({
      vendor_type,
      shop_type,
      store_name,
      contact_person_name,
      mobile_no,
      email,
      full_address,
      city,
      state,
      pin_code,
      gst_status,
      drug_lic_no,
      drug_lic_ex_date,
      password,

      store_pic: {
        url: storeUpload.secure_url,
        publicId: storeUpload.public_id,
      },

      gst_pdf: gstUpload
        ? {
            url: gstUpload.secure_url,
            publicId: gstUpload.public_id,
          }
        : undefined,

      drug_lic_copy: drugUpload
        ? {
            url: drugUpload.secure_url,
            publicId: drugUpload.public_id,
          }
        : undefined,
    });

    return res.status(201).json({
      success: true,
      message: "Vendor registered successfully",
      vendor,
    });
  } catch (error) {
    console.log(error);

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};



