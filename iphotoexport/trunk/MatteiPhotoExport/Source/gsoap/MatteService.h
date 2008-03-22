// Reminder: Modify typemap.dat to customize the header file generated by wsdl2h
/* MatteService.h
   Generated by wsdl2h 1.2.9l from matte.wsdl and typemap.dat
   2007-12-15 00:29:58 GMT
   Copyright (C) 2001-2007 Robert van Engelen, Genivia Inc. All Rights Reserved.
   This part of the software is released under one of the following licenses:
   GPL or Genivia's license for commercial use.
*/

/* NOTE:

 - Compile this file with soapcpp2 to complete the code generation process.
 - Use soapcpp2 option -I to specify paths for #import
   To build with STL, 'stlvector.h' is imported from 'import' dir in package.
 - Use wsdl2h options -c and -s to generate pure C code or C++ code without STL.
 - Use 'typemap.dat' to control schema namespace bindings and type mappings.
   It is strongly recommended to customize the names of the namespace prefixes
   generated by wsdl2h. To do so, modify the prefix bindings in the Namespaces
   section below and add the modified lines to 'typemap.dat' to rerun wsdl2h.
 - Use Doxygen (www.doxygen.org) to browse this file.
 - Use wsdl2h option -l to view the software license terms.

   DO NOT include this file directly into your project.
   Include only the soapcpp2-generated headers and source code files.
*/

//gsoapopt cw

/******************************************************************************\
 *                                                                            *
 * http://msqr.us/matte/ws                                                    *
 *                                                                            *
\******************************************************************************/


/******************************************************************************\
 *                                                                            *
 * Import                                                                     *
 *                                                                            *
\******************************************************************************/

#import "wsse.h"	// wsse = <http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd>
#import "xmime5.h"	// xmime5 = <http://www.w3.org/2005/05/xmlmime>

/******************************************************************************\
 *                                                                            *
 * Schema Namespaces                                                          *
 *                                                                            *
\******************************************************************************/


/* NOTE:

It is strongly recommended to customize the names of the namespace prefixes
generated by wsdl2h. To do so, modify the prefix bindings below and add the
modified lines to typemap.dat to rerun wsdl2h:

mws = "http://msqr.us/matte/ws"
ns1 = ""
m = "http://msqr.us/xsd/matte"

*/

//gsoap ns1   schema namespace:	
//gsoap m     schema namespace:	http://msqr.us/xsd/matte
//gsoap ns1   schema form:	unqualified
//gsoap m     schema elementForm:	qualified
//gsoap m     schema attributeForm:	unqualified

/******************************************************************************\
 *                                                                            *
 * Schema Types                                                               *
 *                                                                            *
\******************************************************************************/


/// Built-in type "xs:base64Binary".
struct xsd__base64Binary
{	unsigned char *__ptr;
	int __size;
	char *id, *type, *options; // NOTE: for DIME and MTOM XOP attachments only
};

/// Built-in type "xs:boolean".
enum xsd__boolean { xsd__boolean__false_, xsd__boolean__true_ };

/// Primitive built-in type "xs:date"
typedef char* xsd__date;

// Imported element "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd":Security declared as _wsse__Security


/// "http://msqr.us/xsd/matte":album-import-sort-type is a simpleType restriction of xs:string.
/// Note: enum values are prefixed with 'm__album_import_sort_type' to avoid name clashes, please use wsdl2h option -e to omit this prefix
enum m__album_import_sort_type
{
/// @brief Sort by date, ascending.
	m__album_import_sort_type__date,	///< xs:string value="date"
};

/// "http://msqr.us/xsd/matte":get-collection-list-request-type is a complexType.
/// @brief Request a list of collections for the authenticated user. This action requires no parameters because a user is only allowed to view their own list of collections. This request can be used to get the list of available collections for a user to import media into.
struct m__get_collection_list_request_type
{
};

/// "http://msqr.us/xsd/matte":get-collection-list-response-type is a complexType.
/// @brief The collection list response: a list of collection names and IDs.
struct m__get_collection_list_response_type
{
/// Size of array of struct m__collection_list_item_type* is 0..unbounded
    int                                  __sizecollection              ;
/// Array of length 0..unbounded
    struct m__collection_list_item_type*  collection                     0;
};

/// "http://msqr.us/xsd/matte":collection-list-item-type is a complexType.
struct m__collection_list_item_type
{
/// Attribute collection-id of type xs:long.
   @LONG64                               collection_id                  1;	///< Required attribute.
/// Attribute name of type xs:string.
   @char*                                name                           1;	///< Required attribute.
};

/// "http://msqr.us/xsd/matte":add-media-request-type is a complexType.
struct m__add_media_request_type
{
/// Element collection-import of type "http://msqr.us/xsd/matte":collection-import-type.
    struct m__collection_import_type*    collection_import              1;	///< Required element.
/// @brief The media to import. This should be a Zip archive of all media files referenced by album items in the associated collection-import element.
/// Element media-data of type "http://msqr.us/xsd/matte":media-data-type.
    struct m__media_data_type*           media_data                     0;	///< Optional element.
/// Attribute collection-id of type xs:long.
   @LONG64                               collection_id                  1;	///< Required attribute.
/// Attribute local-tz of type xs:string.
   @char*                                local_tz                       0;	///< Optional attribute.
/// Attribute media-tz of type xs:string.
   @char*                                media_tz                       0;	///< Optional attribute.
};

/// "http://msqr.us/xsd/matte":add-media-response-type is a complexType.
struct m__add_media_response_type
{
/// Element message of type xs:string.
    char*                                message                        1;	///< Required element.
/// Attribute success of type xs:boolean.
   @enum xsd__boolean                    success                        1;	///< Required attribute.
/// Attribute ticket of type xs:long.
   @LONG64*                              ticket                         0;	///< Optional attribute.
};

/// "http://msqr.us/xsd/matte":collection-import-type is a complexType.
/// @brief Top-level import structure. Imports items into a single Matte collection. May also define albums, or import items directly into collection without associating with albums.
struct m__collection_import_type
{
/// @brief An album to import, which has items nested inside of it.
/// Size of array of struct m__album_import_type* is 0..unbounded
    int                                  __sizealbum                   ;
/// Array of length 0..unbounded
    struct m__album_import_type*         album                          0;
/// @brief A media item to import, outside of any album.
/// Size of array of struct m__item_import_type* is 0..unbounded
    int                                  __sizeitem                    ;
/// Array of length 0..unbounded
    struct m__item_import_type*          item                           0;
/// Attribute name of type xs:string.
   @char*                                name                           0;	///< Optional attribute.
};

/// "http://msqr.us/xsd/matte":base-import-type is an abstract complexType.
/// @brief A base type for both albums and items.
struct m__base_import_type
{
/// @brief A comment or description of the item. This is generally a verbose description of the item.
/// Element comment of type xs:string.
    char*                                comment                        0;	///< Optional element.
/// @brief The name of the item. This is generally a short description.
/// Attribute name of type xs:string.
   @char*                                name                           0;	///< Optional attribute.
};

/// "http://msqr.us/xsd/matte":media-data-type is a complexType with simpleContent.
struct m__media_data_type
{
/// __item wraps 'xs:base64Binary' simpleContent.
    struct xsd__base64Binary             __item                        ;
/// Imported attribute reference "http://www.w3.org/2005/05/xmlmime":contentType.
   @char*                                xmime5__contentType            0;	///< Default value="application/zip".
};

/// "http://msqr.us/xsd/matte":album-import-type is a complexType with complexContent extension of "http://msqr.us/xsd/matte":base-import-type.
/// @brief An import album. The album can specify various attributes like name, comments, a date, and a sort mode. In addition any number of import media items can be specified, so they are added to the album after being imported.
struct m__album_import_type
{
/// INHERITED FROM m__base_import_type:
/// @brief A comment or description of the item. This is generally a verbose description of the item.
/// Element comment of type xs:string.
    char*                                comment                        0;	///< Optional element.
/// @brief The name of the item. This is generally a short description.
/// Attribute name of type xs:string.
   @char*                                name                           0;	///< Optional attribute.
//  END OF INHERITED
/// Size of array of struct m__item_import_type* is 0..unbounded
    int                                  __sizeitem                    ;
/// Array of length 0..unbounded
    struct m__item_import_type*          item                           0;
/// Size of array of struct m__album_import_type* is 0..unbounded
    int                                  __sizealbum                   ;
/// Array of length 0..unbounded
    struct m__album_import_type*         album                          0;
/// Attribute sort of type "http://msqr.us/xsd/matte":album-import-sort-type.
   @enum m__album_import_sort_type       sort                           0 = m__album_import_sort_type__date;	///< Default value="date".
/// Attribute album-date of type xs:date.
   @xsd__date                            album_date                     0;	///< Optional attribute.
/// Attribute creation-date of type xs:dateTime.
   @time_t*                              creation_date                  0;	///< Optional attribute.
/// Attribute modify-date of type xs:dateTime.
   @time_t*                              modify_date                    0;	///< Optional attribute.
};

/// "http://msqr.us/xsd/matte":item-import-type is a complexType with complexContent extension of "http://msqr.us/xsd/matte":base-import-type.
/// @brief An import media item. The item can specify various attributes like name, comments, keywords, and a rating. The archive-path element refers to the zip archive path of this item as located in the associated zip archive used for this import.
struct m__item_import_type
{
/// INHERITED FROM m__base_import_type:
/// @brief A comment or description of the item. This is generally a verbose description of the item.
/// Element comment of type xs:string.
    char*                                comment                        0;	///< Optional element.
/// @brief The name of the item. This is generally a short description.
/// Attribute name of type xs:string.
   @char*                                name                           0;	///< Optional attribute.
//  END OF INHERITED
/// @brief Any number of keywords can be specified by delimiting them with commas.
/// Element keywords of type xs:string.
    char*                                keywords                       0;	///< Optional element.
/// Size of array of struct m__metadata_import_type* is 0..unbounded
    int                                  __sizemeta                    ;
/// Array of length 0..unbounded
    struct m__metadata_import_type*      meta                           0;
/// @brief The full path of this media item within the associated zip archive of this import.
/// Attribute archive-path of type xs:string.
   @char*                                archive_path                   1;	///< Required attribute.
/// @brief A numeric rating to assign to this item.
/// Attribute rating of type xs:float.
   @float*                               rating                         0;	///< Optional attribute.
};

/// "http://msqr.us/xsd/matte":metadata-import-type is a complexType with simpleContent.
struct m__metadata_import_type
{
/// __item wraps 'xs:string' simpleContent.
    char*                                __item                        ;
/// Attribute name of type xs:string.
   @char*                                name                           0;	///< Optional attribute.
};

/// Element "http://msqr.us/xsd/matte":GetCollectionListRequest of type "http://msqr.us/xsd/matte":get-collection-list-request-type.
/// Note: use wsdl2h option -g to generate this global element declaration.

/// Element "http://msqr.us/xsd/matte":GetCollectionListResponse of type "http://msqr.us/xsd/matte":get-collection-list-response-type.
/// Note: use wsdl2h option -g to generate this global element declaration.

/// Element "http://msqr.us/xsd/matte":AddMediaRequest of type "http://msqr.us/xsd/matte":add-media-request-type.
/// Note: use wsdl2h option -g to generate this global element declaration.

/// Element "http://msqr.us/xsd/matte":AddMediaResponse of type "http://msqr.us/xsd/matte":add-media-response-type.
/// Note: use wsdl2h option -g to generate this global element declaration.

/// Element "http://msqr.us/xsd/matte":collection-import of type "http://msqr.us/xsd/matte":collection-import-type.
/// Note: use wsdl2h option -g to generate this global element declaration.

/******************************************************************************\
 *                                                                            *
 * Services                                                                   *
 *                                                                            *
\******************************************************************************/


//gsoap mws  service name:	MatteSoapBinding 
//gsoap mws  service type:	MattePortType 
//gsoap mws  service port:	http://localhost:8080/matte/ws/Matte 
//gsoap mws  service namespace:	http://msqr.us/matte/ws 
//gsoap mws  service transport:	http://schemas.xmlsoap.org/soap/http 

/** @mainpage Service Definitions

@section Service_bindings Bindings
  - @ref MatteSoapBinding

*/

/**

@page MatteSoapBinding Binding "MatteSoapBinding"

@section MatteSoapBinding_operations Operations of Binding  "MatteSoapBinding"
  - @ref __mws__GetCollectionList
  - @ref __mws__AddMedia

@section MatteSoapBinding_ports Endpoints of Binding  "MatteSoapBinding"
  - http://localhost:8080/matte/ws/Matte

Note: use wsdl2h option -N to change the service binding prefix name

*/

/******************************************************************************\
 *                                                                            *
 * SOAP Header                                                                *
 *                                                                            *
\******************************************************************************/

/**

The SOAP Header is part of the gSOAP context and its content is accessed
through the soap.header variable. You may have to set the soap.actor variable
to serialize SOAP Headers with SOAP-ENV:actor or SOAP-ENV:role attributes.
Use option -j to omit.

*/
struct SOAP_ENV__Header
{
    mustUnderstand                       // must be understood by receiver
    _wsse__Security*                     wsse__Security                ;	///< TODO: Please check element name and type (imported type)

};

/******************************************************************************\
 *                                                                            *
 * MatteSoapBinding                                                           *
 *                                                                            *
\******************************************************************************/


/******************************************************************************\
 *                                                                            *
 * __mws__GetCollectionList                                                   *
 *                                                                            *
\******************************************************************************/


/// Operation "__mws__GetCollectionList" of service binding "MatteSoapBinding"

/**

Operation details:

  - SOAP document/literal style
  - SOAP action="http://msqr.us/matte/ws/GetCollectionList"
  - Request message has mandatory header part(s):
    - wsse__Security

C stub function (defined in soapClient.c[pp] generated by soapcpp2):
@code
  int soap_call___mws__GetCollectionList(
    struct soap *soap,
    NULL, // char *endpoint = NULL selects default endpoint for this operation
    NULL, // char *action = NULL selects default action for this operation
    // request parameters:
    struct m__get_collection_list_request_type* m__GetCollectionListRequest,
    // response parameters:
    struct m__get_collection_list_response_type* m__GetCollectionListResponse
  );
@endcode

C server function (called from the service dispatcher defined in soapServer.c[pp]):
@code
  int __mws__GetCollectionList(
    struct soap *soap,
    // request parameters:
    struct m__get_collection_list_request_type* m__GetCollectionListRequest,
    // response parameters:
    struct m__get_collection_list_response_type* m__GetCollectionListResponse
  );
@endcode

*/

//gsoap mws  service method-style:	GetCollectionList document
//gsoap mws  service method-encoding:	GetCollectionList literal
//gsoap mws  service method-action:	GetCollectionList http://msqr.us/matte/ws/GetCollectionList
//gsoap mws  service method-input-header-part:	GetCollectionList wsse__Security
int __mws__GetCollectionList(
    struct m__get_collection_list_request_type* m__GetCollectionListRequest,	///< Request parameter
    struct m__get_collection_list_response_type* m__GetCollectionListResponse	///< Response parameter
);

/******************************************************************************\
 *                                                                            *
 * __mws__AddMedia                                                            *
 *                                                                            *
\******************************************************************************/


/// Operation "__mws__AddMedia" of service binding "MatteSoapBinding"

/**

Operation details:

  - SOAP document/literal style
  - SOAP action="http://msqr.us/matte/ws/AddMedia"
  - Request message has mandatory header part(s):
    - wsse__Security

C stub function (defined in soapClient.c[pp] generated by soapcpp2):
@code
  int soap_call___mws__AddMedia(
    struct soap *soap,
    NULL, // char *endpoint = NULL selects default endpoint for this operation
    NULL, // char *action = NULL selects default action for this operation
    // request parameters:
    struct m__add_media_request_type*   m__AddMediaRequest,
    // response parameters:
    struct m__add_media_response_type*  m__AddMediaResponse
  );
@endcode

C server function (called from the service dispatcher defined in soapServer.c[pp]):
@code
  int __mws__AddMedia(
    struct soap *soap,
    // request parameters:
    struct m__add_media_request_type*   m__AddMediaRequest,
    // response parameters:
    struct m__add_media_response_type*  m__AddMediaResponse
  );
@endcode

*/

//gsoap mws  service method-style:	AddMedia document
//gsoap mws  service method-encoding:	AddMedia literal
//gsoap mws  service method-action:	AddMedia http://msqr.us/matte/ws/AddMedia
//gsoap mws  service method-input-header-part:	AddMedia wsse__Security
int __mws__AddMedia(
    struct m__add_media_request_type*   m__AddMediaRequest,	///< Request parameter
    struct m__add_media_response_type*  m__AddMediaResponse	///< Response parameter
);

/* End of MatteService.h */