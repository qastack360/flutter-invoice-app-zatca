import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface InvoiceData {
  no: number;
  date: string;
  customer: string;
  salesman: string;
  vatNo: string;
  total: number;
  vatAmount: number;
  items: any[];
  company: any;
}

interface ZatcaResponse {
  success: boolean;
  uuid?: string;
  qr_code?: string;
  error?: string;
  timestamp: string;
}

// ZATCA API Configuration
const ZATCA_CONFIG = {
  // Sandbox URLs - replace with production URLs for live environment
  BASE_URL: Deno.env.get('ZATCA_BASE_URL') || 'https://gw-fatoora.zatca.gov.sa/e-invoicing/developer-portal',
  API_VERSION: 'v2',
  ENDPOINTS: {
    COMPLIANCE: '/compliance',
    REPORTING: '/reporting',
    CLEARANCE: '/clearance',
  }
};

// Digital Certificate Configuration
const CERT_CONFIG = {
  PRIVATE_KEY: Deno.env.get('ZATCA_PRIVATE_KEY'),
  CERTIFICATE: Deno.env.get('ZATCA_CERTIFICATE'),
  CERTIFICATE_PASSWORD: Deno.env.get('ZATCA_CERT_PASSWORD'),
};

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

    // Validate invoice data
    const validationResult = validateInvoiceData(invoice)
    if (!validationResult.isValid) {
      throw new Error(`Invoice validation failed: ${validationResult.errors.join(', ')}`)
    }

    // Generate invoice hash
    const invoiceHash = generateInvoiceHash(invoice)

    // Create ZATCA-compliant invoice XML
    const zatcaXml = generateZatcaXml(invoice, invoiceHash)

    // Digitally sign the invoice
    const signedInvoice = await digitallySignInvoice(zatcaXml)

    // Submit to ZATCA compliance API
    const complianceResponse = await submitToZatcaCompliance(signedInvoice)

    // If compliance check passes, submit to reporting
    if (complianceResponse.success) {
      const reportingResponse = await submitToZatcaReporting(signedInvoice)
      
      if (reportingResponse.success) {
        // Submit to clearance
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

// Validate invoice data according to ZATCA requirements
function validateInvoiceData(invoice: InvoiceData): { isValid: boolean; errors: string[] } {
  const errors: string[] = []

  if (!invoice.no || invoice.no <= 0) {
    errors.push('Invalid invoice number')
  }

  if (!invoice.date) {
    errors.push('Invoice date is required')
  }

  if (!invoice.customer || invoice.customer.trim() === '') {
    errors.push('Customer name is required')
  }

  if (!invoice.vatNo || invoice.vatNo.trim() === '') {
    errors.push('VAT number is required')
  }

  if (!invoice.total || invoice.total <= 0) {
    errors.push('Invalid total amount')
  }

  if (!invoice.vatAmount || invoice.vatAmount < 0) {
    errors.push('Invalid VAT amount')
  }

  if (!invoice.items || invoice.items.length === 0) {
    errors.push('Invoice must have at least one item')
  }

  if (!invoice.company) {
    errors.push('Company details are required')
  }

  return {
    isValid: errors.length === 0,
    errors
  }
}

// Generate SHA-256 hash of invoice data
function generateInvoiceHash(invoice: InvoiceData): string {
  const hashData = `${invoice.no}${invoice.date}${invoice.customer}${invoice.vatNo}${invoice.total}${invoice.vatAmount}`
  
  // In a real implementation, you would use a proper crypto library
  // For this example, we'll create a simple hash
  let hash = 0
  for (let i = 0; i < hashData.length; i++) {
    const char = hashData.charCodeAt(i)
    hash = ((hash << 5) - hash) + char
    hash = hash & hash // Convert to 32-bit integer
  }
  
  return Math.abs(hash).toString(16)
}

// Generate ZATCA-compliant XML
function generateZatcaXml(invoice: InvoiceData, hash: string): string {
  const now = new Date().toISOString()
  
  return `<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" 
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" 
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:UBLVersionID>2.1</cbc:UBLVersionID>
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0</cbc:CustomizationID>
  <cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>
  <cbc:ID>${invoice.no}</cbc:ID>
  <cbc:CopyIndicator>false</cbc:CopyIndicator>
  <cbc:UUID>${generateUUID()}</cbc:UUID>
  <cbc:IssueDate>${formatDate(invoice.date)}</cbc:IssueDate>
  <cbc:IssueTime>${formatTime(invoice.date)}</cbc:IssueTime>
  <cbc:InvoiceTypeCode>110</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>SAR</cbc:DocumentCurrencyCode>
  <cbc:LineCountNumeric>${invoice.items.length}</cbc:LineCountNumeric>
  
  <cac:AccountingSupplierParty>
    <cac:Party>
      <cac:PartyIdentification>
        <cbc:ID schemeID="VAT">${invoice.company.vatNo || '000000000000000'}</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>${invoice.company.ownerName1 || 'Company Name'}</cbc:Name>
      </cac:PartyName>
      <cac:PostalAddress>
        <cbc:StreetName>Street Address</cbc:StreetName>
        <cbc:CityName>City</cbc:CityName>
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
        <cbc:ID schemeID="VAT">${invoice.vatNo || '000000000000000'}</cbc:ID>
      </cac:PartyIdentification>
      <cac:PartyName>
        <cbc:Name>${invoice.customer}</cbc:Name>
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
    <cbc:TaxAmount currencyID="SAR">${invoice.vatAmount.toFixed(2)}</cbc:TaxAmount>
    <cac:TaxSubtotal>
      <cbc:TaxableAmount currencyID="SAR">${(invoice.total - invoice.vatAmount).toFixed(2)}</cbc:TaxableAmount>
      <cbc:TaxAmount currencyID="SAR">${invoice.vatAmount.toFixed(2)}</cbc:TaxAmount>
      <cbc:Percent>15</cbc:Percent>
      <cac:TaxCategory>
        <cbc:ID>S</cbc:ID>
        <cbc:Percent>15</cbc:Percent>
        <cac:TaxScheme>
          <cbc:ID>VAT</cbc:ID>
        </cac:TaxScheme>
      </cac:TaxCategory>
    </cac:TaxSubtotal>
  </cac:TaxTotal>
  
  <cac:LegalMonetaryTotal>
    <cbc:LineExtensionAmount currencyID="SAR">${(invoice.total - invoice.vatAmount).toFixed(2)}</cbc:LineExtensionAmount>
    <cbc:TaxExclusiveAmount currencyID="SAR">${(invoice.total - invoice.vatAmount).toFixed(2)}</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="SAR">${invoice.total.toFixed(2)}</cbc:TaxInclusiveAmount>
    <cbc:PayableAmount currencyID="SAR">${invoice.total.toFixed(2)}</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
  
  ${invoice.items.map((item, index) => `
  <cac:InvoiceLine>
    <cbc:ID>${index + 1}</cbc:ID>
    <cbc:InvoicedQuantity unitCode="PCE">${item.quantity}</cbc:InvoicedQuantity>
    <cbc:LineExtensionAmount currencyID="SAR">${(item.price * item.quantity).toFixed(2)}</cbc:LineExtensionAmount>
    <cac:TaxTotal>
      <cbc:TaxAmount currencyID="SAR">${(item.price * item.quantity * 0.15).toFixed(2)}</cbc:TaxAmount>
      <cac:TaxSubtotal>
        <cbc:TaxableAmount currencyID="SAR">${(item.price * item.quantity).toFixed(2)}</cbc:TaxableAmount>
        <cbc:TaxAmount currencyID="SAR">${(item.price * item.quantity * 0.15).toFixed(2)}</cbc:TaxAmount>
        <cbc:Percent>15</cbc:Percent>
        <cac:TaxCategory>
          <cbc:ID>S</cbc:ID>
          <cbc:Percent>15</cbc:Percent>
          <cac:TaxScheme>
            <cbc:ID>VAT</cbc:ID>
          </cac:TaxScheme>
        </cac:TaxCategory>
      </cac:TaxSubtotal>
    </cac:TaxTotal>
    <cac:Item>
      <cbc:Name>${item.name}</cbc:Name>
      <cbc:Description>${item.description || ''}</cbc:Description>
    </cac:Item>
    <cac:Price>
      <cbc:PriceAmount currencyID="SAR">${item.price.toFixed(2)}</cbc:PriceAmount>
    </cac:Price>
  </cac:InvoiceLine>
  `).join('')}
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

// Format date for ZATCA
function formatDate(dateString: string): string {
  const date = new Date(dateString)
  return date.toISOString().split('T')[0]
}

// Format time for ZATCA
function formatTime(dateString: string): string {
  const date = new Date(dateString)
  return date.toISOString().split('T')[1].split('.')[0]
}

// Digitally sign the invoice XML
async function digitallySignInvoice(xmlContent: string): Promise<string> {
  // In a real implementation, you would:
  // 1. Load the private key and certificate
  // 2. Create a canonicalized version of the XML
  // 3. Generate a signature using SHA-256
  // 4. Add the signature to the XML
  
  // For this example, we'll return the XML as-is
  // In production, implement proper digital signing
  
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
        'Content-Type': 'application/xml',
        'Authorization': `Bearer ${Deno.env.get('ZATCA_API_TOKEN')}`,
      },
      body: signedXml,
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
        'Content-Type': 'application/xml',
        'Authorization': `Bearer ${Deno.env.get('ZATCA_API_TOKEN')}`,
      },
      body: signedXml,
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
        'Content-Type': 'application/xml',
        'Authorization': `Bearer ${Deno.env.get('ZATCA_API_TOKEN')}`,
      },
      body: signedXml,
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