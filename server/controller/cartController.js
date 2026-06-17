import jwt from "jsonwebtoken";
import product from "../model/productModel.js";
import User from "../model/userModel.js";

const cart = async (req, res) => {
  try {
    const token = req.cookies.token;

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Please login first",
      });
    }

    const decoded = jwt.verify(
      token,
      process.env.SECRET_KEY
    );

    req.id = decoded.userId;

    console.log(decoded, "This is decoded");
    console.log(req.id, "User ID");

    return res.status(200).json({
      success: true,
      userId: req.id,
    });

  } catch (error) {
    return res.status(401).json({
      success: false,
      message: "Invalid token",
    });
  }
};

export default cart;


 export const  deleteProduct = async( req, res ) =>{
       
      try{
         
        const product_id = req.params.id ;

        console.log("Product id is : " , product_id ) ;

        const get_product = await product.findById(product_id) ;
        console.log("product is : " , get_product ) ;


        if( ! get_product ) {
          return res.status(401)
          .json({ 
            message : " Product not found ",
            success : false 
          });
        }

        await product.findByIdAndDelete(product_id ) ;
        return res.status(201)
        .json({ 
          message :"Product deleted succesfully " ,
          success : true 
        })
      }
      catch(er) {
        console.log(er , " er is")
      }

}

export const getAllProducts =async(req , res ) =>{

    try{
        const products =await product.find() ;

        if( !products )
          return res.status(401)
        .json({ 
          message :"Product not found ",
          success :false 
        }) ;

        return res.status(200)
        .json({ 
            message :"all products are fetched successfully ",
            success : true ,
            products
        });


    }
    catch(er){
        console.log(er , " error from fetch all product ") ;
    }
}


// add cart logic 

export const addCart = async (req, res) => {
  try {

    const product_id = req.params.id;
    const userId = req.id;

    console.log(product_id, "product id is:");
    console.log(userId, "user id is:");

    const get_product = await product.findById(product_id ) ;
    const user =        await User.findById(userId ) ;

    // console.log( "product details is " , get_product , "<br>" );
    // console.log( " user details is " , user );

    const itemIndex = user.cart.itemIndex() 

    return res.status(201)
    .json({ 
      message :"Product add to cart ",
      success : true 
    });
  }
  catch(er){
     console.log("error is :" , er ) ;
  }
}