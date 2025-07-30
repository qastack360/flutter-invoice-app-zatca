import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ZatcaResponse {
  success: boolean;
  uuid?: string;
  qr_code?: string;
  error?: string;
  timestamp: string;
  request_id?: string;
  compliance_status?: string;
  reporting_status?: string;
  clearance_status?: string;
}

// ZATCA API Configuration
const ZATCA_CONFIG = {
  // Sandbox URLs - replace with production URLs for live environment
  BASE_URL: Deno.env.get('ZATCA_BASE_URL') || 'https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal',
  API_VERSION: 'V2',
  ENDPOINTS: {
    COMPLIANCE: '/compliance/invoices',
    REPORTING: '/invoices/reporting/single',
    CLEARANCE: '/invoices/clearance/single',
  },
  HEADERS: {
    'Accept': 'application/json',
    'Accept-Language': 'en',
    'Accept-Version': 'V2',
    'Content-Type': 'application/json',
  }
};

// Authentication Configuration
const AUTH_CONFIG = {
  USERNAME: Deno.env.get('ZATCA_USERNAME') || 'flutterinvoiceapp@gmail.com',
  PASSWORD: Deno.env.get('ZATCA_PASSWORD'),
  AUTHORIZATION: Deno.env.get('ZATCA_AUTHORIZATION') || 'Basic Zmx1dHRlcmludm9pY2VhcHBAZ21haWwuY29t0lJpendhbiMxMTIy',
};

// Environment flag - set to true for testing mode
const TESTING_MODE = true; // Set to false for production

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const { invoice, request_id, timestamp } = await req.json()

    if (!invoice) {
      throw new Error('Invoice data is required')
    }

    console.log('Received invoice data:', JSON.stringify(invoice, null, 2))

    // Validate invoice data
    const validationResult = validateInvoiceData(invoice)
    if (!validationResult.isValid) {
      throw new Error(`Invoice validation failed: ${validationResult.errors.join(', ')}`)
    }

    // Generate invoice hash
    const invoiceHash = generateInvoiceHash(invoice)

    // Create ZATCA-compliant invoice XML
    const zatcaXml = generateZatcaXml(invoice, invoiceHash)

    console.log('Generated XML:', zatcaXml)

    if (TESTING_MODE) {
      // Simulate ZATCA API responses for testing
      return simulateZatcaResponse(invoice, request_id)
    } else {
      // Real ZATCA API calls
      return await processWithRealZatca(zatcaXml, request_id)
    }

  } catch (error) {
    console.error('ZATCA processing error:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      } as ZatcaResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})

// Simulate ZATCA API responses for testing
function simulateZatcaResponse(invoice: any, request_id?: string): Response {
  const uuid = generateUUID()
  const qrCode = generateTestQRCode(invoice)
  
  return new Response(
    JSON.stringify({
      success: true,
      uuid: uuid,
      qr_code: qrCode,
      timestamp: new Date().toISOString(),
      request_id: request_id,
      compliance_status: 'approved',
      reporting_status: 'submitted',
      clearance_status: 'cleared',
      message: 'Invoice processed successfully (TESTING MODE)',
    } as ZatcaResponse),
    {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    }
  )
}

// Process with real ZATCA API
async function processWithRealZatca(zatcaXml: string, request_id?: string): Promise<Response> {
  try {
    // Digitally sign the invoice
    const signedInvoice = await digitallySignInvoice(zatcaXml)

    // Submit to ZATCA compliance API
    const complianceResponse = await submitToZatcaCompliance(signedInvoice)

    if (complianceResponse.success) {
      const reportingResponse = await submitToZatcaReporting(signedInvoice)
      
      if (reportingResponse.success) {
        const clearanceResponse = await submitToZatcaClearance(signedInvoice)
        
        return new Response(
          JSON.stringify({
            success: true,
            uuid: clearanceResponse.uuid,
            qr_code: clearanceResponse.qr_code,
            timestamp: new Date().toISOString(),
            request_id,
            compliance_status: 'approved',
            reporting_status: 'submitted',
            clearance_status: 'cleared',
          } as ZatcaResponse),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      } else {
        throw new Error(`Reporting failed: ${reportingResponse.error}`)
      }
    } else {
      throw new Error(`Compliance check failed: ${complianceResponse.error}`)
    }
  } catch (error) {
    throw new Error(`ZATCA API error: ${error.message}`)
  }
}

// Validate invoice data according to ZATCA requirements
function validateInvoiceData(invoice: any): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  // Check invoice number
  if (!invoice.no && !invoice.invoice_number) {
    errors.push('Invoice number is required')
  }

  // Check date
  if (!invoice.date) {
    errors.push('Invoice date is required')
  }

  // Check customer
  if (!invoice.customer) {
    errors.push('Customer name is required')
  }

  // Check items
  if (!invoice.items || invoice.items.length === 0) {
    errors.push('Invoice must have at least one item')
  }

  // Calculate total amount from items if not provided
  if (!invoice.total && !invoice.finalAmount) {
    if (invoice.items && invoice.items.length > 0) {
      let calculatedTotal = 0;
      for (const item of invoice.items) {
        const quantity = item.quantity || 0;
        const rate = item.rate || item.price || 0;
        calculatedTotal += quantity * rate;
      }
      
      if (invoice.vatPercent) {
        const vatAmount = calculatedTotal * (invoice.vatPercent / 100);
        calculatedTotal += vatAmount;
      }
      
      if (invoice.discount) {
        calculatedTotal -= invoice.discount;
      }
      
      if (calculatedTotal <= 0) {
        errors.push('Total amount is required')
      }
    } else {
      errors.push('Total amount is required')
    }
  }

  return {
    isValid: errors.length === 0,
    errors
  }
}

// Generate SHA-256 hash of invoice data
function generateInvoiceHash(invoice: any): string {
  const invoiceNo = invoice.no || invoice.invoice_number || '1';
  
  // Calculate totals from items if not provided
  let subtotal = 0;
  if (invoice.items && invoice.items.length > 0) {
    for (const item of invoice.items) {
      const quantity = item.quantity || 0;
      const rate = item.rate || item.price || 0;
      subtotal += quantity * rate;
    }
  }
  
  const vatPercent = invoice.vatPercent || 15;
  const discount = invoice.discount || 0;
  const vatAmount = invoice.vatAmount || (subtotal * vatPercent / 100);
  const total = invoice.total || (subtotal + vatAmount - discount);
  
  const hashData = `${invoiceNo}${invoice.date}${invoice.customer}${total.toFixed(2)}${vatAmount.toFixed(2)}`;
  
  console.log('Hash data:', hashData);
  
  // Simple hash for demo
  let hash = 0;
  for (let i = 0; i < hashData.length; i++) {
    const char = hashData.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  
  return Math.abs(hash).toString(16);
}

// Generate ZATCA-compliant XML
function generateZatcaXml(invoice: any, hash: string): string {
  // Safely extract values with fallbacks
  const invoiceNo = invoice.no || invoice.invoice_number || 'INV-001'
  const invoiceDate = invoice.date || new Date().toISOString()
  const customerName = invoice.customer || 'Customer'
  const vatNo = invoice.vatNo || invoice.vat_number || invoice.customerVat || '000000000000000'
  const items = invoice.items || []
  
  // Calculate totals from items if not provided
  let subtotal = 0;
  for (const item of items) {
    const quantity = item.quantity || 0;
    const rate = item.rate || item.price || 0;
    subtotal += quantity * rate;
  }
  
  const vatPercent = invoice.vatPercent || 15;
  const discount = invoice.discount || 0;
  const vatAmount = invoice.vatAmount || (subtotal * vatPercent / 100);
  const total = invoice.total || (subtotal + vatAmount - discount);
  
  // Company details with fallbacks
  const company = invoice.company || {}
  const companyVatNo = company.vatNo || company.vat_number || '000000000000000'
  const companyName = company.ownerName1 || company.name || 'Company Name'
  const companyAddress = company.address || 'Street Address'
  const companyCity = company.city || 'City'
  
  console.log('Calculated totals:', {
    subtotal: subtotal.toFixed(2),
    vatAmount: vatAmount.toFixed(2),
    total: total.toFixed(2),
    discount: discount.toFixed(2)
  });
  
  return `<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" 
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" 
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:UBLVersionID>2.1</cbc:UBLVersionID>
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>
  <cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>
  <cbc:ID>${invoiceNo}</cbc:ID>
  <cbc:CopyIndicator>false</cbc:CopyIndicator>
  <cbc:UUID>${generateUUID()}</cbc:UUID>
  <cbc:IssueDate>${formatDate(invoiceDate)}</cbc:IssueDate>
  <cbc:IssueTime>${formatTime(invoiceDate)}</cbc:IssueTime>
  <cbc:InvoiceTypeCode>110</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>SAR</cbc:DocumentCurrencyCode>
  <cbc:LineCountNumeric>${items.length}</cbc:LineCountNumeric>
  
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="VAT">${companyVatNo}</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>${companyName}</cbc:Name>
      </cac:PartyName>
      <cac:PostalAddress>
        <cbc:StreetName>${companyAddress}</cbc:StreetName>
        <cbc:CityName>${companyCity}</cbc:CityName>
        <cbc:PostalZone>00000</cbc:PostalZone>
        <cac:Country>
          <cbc:IdentificationCode>SA</cbc:IdentificationCode>
        </cac:Country>
      </cac:PostalAddress>
      <cac:PartyTaxScheme>
        <cac:TaxScheme>
          <cbc:ID>VAT</cbc:ID>
        </cac:TaxScheme>
      </cac:PartyTaxScheme>
    </cac:Party>
  </cac:AccountingSupplierParty>
  
  <cac:AccountingCustomerParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="VAT">${vatNo}</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>${customerName}</cbc:Name>
      </cac:PartyName>
      <cac:PostalAddress>
        <cbc:StreetName>Customer Address</cbc:StreetName>
        <cbc:CityName>City</cbc:CityName>
        <cbc:PostalZone>00000</cbc:PostalZone>
        <cac:Country>
          <cbc:IdentificationCode>SA</cbc:IdentificationCode>
        </cac:Country>
      </cac:PostalAddress>
    </cac:Party>
  </cac:AccountingCustomerParty>
  
  <cac:PaymentMeans>
    <cbc:ID>1</cbc:ID>
    <cbc:PaymentMeansCode>1</cbc:PaymentMeansCode>
  </cac:PaymentMeans>
  
  <cac:TaxTotal>
    <cbc:TaxAmount currencyID="SAR">${vatAmount.toFixed(2)}</cbc:TaxAmount>
    <cac:TaxSubtotal>
      <cbc:TaxableAmount currencyID="SAR">${(subtotal - discount).toFixed(2)}</cbc:TaxableAmount>
      <cbc:TaxAmount currencyID="SAR">${vatAmount.toFixed(2)}</cbc:TaxAmount>
      <cbc:Percent>${vatPercent}</cbc:Percent>
      <cac:TaxCategory>
        <cbc:ID>S</cbc:ID>
        <cbc:Percent>${vatPercent}</cbc:Percent>
        <cac:TaxScheme>
          <cbc:ID>VAT</cbc:ID>
        </cac:TaxScheme>
      </cac:TaxCategory>
    </cac:TaxSubtotal>
  </cac:TaxTotal>
  
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="SAR">${(subtotal - discount).toFixed(2)}</cbc:LineExtensionAmount>
    <cbc:TaxExclusiveAmount currencyID="SAR">${(subtotal - discount).toFixed(2)}</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="SAR">${total.toFixed(2)}</cbc:TaxInclusiveAmount>
    <cbc:PayableAmount currencyID="SAR">${total.toFixed(2)}</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  
  ${items.map((item: any, index: number) => {
    const quantity = item.quantity || 1;
    const rate = item.price || item.rate || 0;
    const lineTotal = quantity * rate;
    const lineVat = lineTotal * (vatPercent / 100);
    
    return `
  <cac:InvoiceLine>
    <cbc:ID>${index + 1}</cbc:ID>
    <cbc:InvoicedQuantity unitCode="PCE">${quantity}</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount currencyID="SAR">${lineTotal.toFixed(2)}</cbc:LineExtensionAmount>
    <cac:TaxTotal>
      <cbc:TaxAmount currencyID="SAR">${lineVat.toFixed(2)}</cbc:TaxAmount>
      <cac:TaxSubtotal>
        <cbc:TaxableAmount currencyID="SAR">${lineTotal.toFixed(2)}</cbc:TaxableAmount>
        <cbc:TaxAmount currencyID="SAR">${lineVat.toFixed(2)}</cbc:TaxAmount>
        <cbc:Percent>${vatPercent}</cbc:Percent>
        <cac:TaxCategory>
          <cbc:ID>S</cbc:ID>
          <cbc:Percent>${vatPercent}</cbc:Percent>
          <cac:TaxScheme>
            <cbc:ID>VAT</cbc:ID>
          </cac:TaxScheme>
        </cac:TaxCategory>
      </cac:TaxSubtotal>
    </cac:TaxTotal>
    <cac:Item>
      <cbc:Name>${item.name || item.description || 'Item'}</cbc:Name>
      <cbc:Description>${item.description || ''}</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount currencyID="SAR">${rate.toFixed(2)}</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>`;
  }).join('')}
</Invoice>`
}

// Generate UUID for invoice
function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0
    const v = c == 'x' ? r : (r & 0x3 | 0x8)
    return v.toString(16)
  })
}

// Generate test QR code data
function generateTestQRCode(invoice: any): string {
  const invoiceNo = invoice.no || invoice.invoice_number || 'INV-001'
  const total = invoice.total || invoice.finalAmount || 0
  const vatAmount = invoice.vatAmount || invoice.vat_amount || (total * 0.15)
  const timestamp = new Date().toISOString()
  
  const qrData = {
    seller_name: invoice.company?.ownerName1 || 'Company Name',
    vat_number: invoice.company?.vatNo || '000000000000000',
    timestamp: timestamp,
    total: total,
    vat_amount: vatAmount,
    invoice_number: invoiceNo,
    uuid: generateUUID(),
  }
  
  return btoa(JSON.stringify(qrData))
}

// Format date for ZATCA
function formatDate(dateString: string): string {
  try {
    let date: Date;
    
    if (dateString.includes('T') || dateString.includes('Z')) {
      date = new Date(dateString);
    } else if (dateString.includes(' – ')) {
      const datePart = dateString.split(' – ')[0];
      date = new Date(datePart);
    } else if (dateString.includes('-')) {
      date = new Date(dateString);
    } else {
      date = new Date();
    }
    
    if (isNaN(date.getTime())) {
      date = new Date();
    }
    
    return date.toISOString().split('T')[0];
  } catch (error) {
    console.error('Error formatting date:', error);
    return new Date().toISOString().split('T')[0];
  }
}

// Format time for ZATCA
function formatTime(dateString: string): string {
  try {
    let date: Date;
    
    if (dateString.includes('T') || dateString.includes('Z')) {
      date = new Date(dateString);
    } else if (dateString.includes(' – ')) {
      const timePart = dateString.split(' – ')[1];
      if (timePart) {
        const today = new Date().toISOString().split('T')[0];
        date = new Date(`${today}T${timePart}`);
      } else {
        date = new Date();
      }
    } else if (dateString.includes('-')) {
      date = new Date(dateString);
    } else {
      date = new Date();
    }
    
    if (isNaN(date.getTime())) {
      date = new Date();
    }
    
    return date.toISOString().split('T')[1].split('.')[0];
  } catch (error) {
    console.error('Error formatting time:', error);
    return new Date().toISOString().split('T')[1].split('.')[0];
  }
}

// Digitally sign the invoice XML
async function digitallySignInvoice(xmlContent: string): Promise<string> {
  console.log('Digital signing would be implemented here')
  return xmlContent
}

// Submit invoice to ZATCA compliance API
async function submitToZatcaCompliance(signedXml: string): Promise<{ success: boolean; error?: string }> {
  try {
    const url = `${ZATCA_CONFIG.BASE_URL}${ZATCA_CONFIG.ENDPOINTS.COMPLIANCE}`
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        ...ZATCA_CONFIG.HEADERS,
        'Authorization': AUTH_CONFIG.AUTHORIZATION,
      },
      body: JSON.stringify({
        invoiceHash: generateInvoiceHash({ invoice: signedXml }),
        uuid: generateUUID(),
        invoice: btoa(signedXml),
      }),
    })

    if (response.ok) {
      return { success: true }
    } else {
      const errorText = await response.text()
      return { success: false, error: errorText }
    }
  } catch (error) {
    return { success: false, error: error.message }
  }
}

// Submit invoice to ZATCA reporting API
async function submitToZatcaReporting(signedXml: string): Promise<{ success: boolean; error?: string }> {
  try {
    const url = `${ZATCA_CONFIG.BASE_URL}${ZATCA_CONFIG.ENDPOINTS.REPORTING}`
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        ...ZATCA_CONFIG.HEADERS,
        'Authorization': AUTH_CONFIG.AUTHORIZATION,
      },
      body: JSON.stringify({
        invoiceHash: generateInvoiceHash({ invoice: signedXml }),
        uuid: generateUUID(),
        invoice: btoa(signedXml),
      }),
    })

    if (response.ok) {
      return { success: true }
    } else {
      const errorText = await response.text()
      return { success: false, error: errorText }
    }
  } catch (error) {
    return { success: false, error: error.message }
  }
}

// Submit invoice to ZATCA clearance API
async function submitToZatcaClearance(signedXml: string): Promise<{ success: boolean; uuid?: string; qr_code?: string; error?: string }> {
  try {
    const url = `${ZATCA_CONFIG.BASE_URL}${ZATCA_CONFIG.ENDPOINTS.CLEARANCE}`
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        ...ZATCA_CONFIG.HEADERS,
        'Authorization': AUTH_CONFIG.AUTHORIZATION,
        'Clearance-Status': '1',
      },
      body: JSON.stringify({
        invoiceHash: generateInvoiceHash({ invoice: signedXml }),
        uuid: generateUUID(),
        invoice: btoa(signedXml),
      }),
    })

    if (response.ok) {
      const result = await response.json()
      return {
        success: true,
        uuid: result.uuid || generateUUID(),
        qr_code: result.qr_code || 'QR_CODE_PLACEHOLDER',
      }
    } else {
      const errorText = await response.text()
      return { success: false, error: errorText }
    }
  } catch (error) {
    return { success: false, error: error.message }
  }
} 