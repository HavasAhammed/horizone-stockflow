import { Request, Response, NextFunction } from 'express';
import { dataService } from '../services/dataService.js';

export const getCustomers = (req: Request, res: Response, next: NextFunction) => {
  try {
    const { search } = req.query;
    let customers = dataService.getAllCustomers();
    if (search && typeof search === 'string') {
      const q = search.toLowerCase().trim();
      customers = customers.filter(
        (c) =>
          c.consumerNumber.toLowerCase().includes(q) ||
          c.phone.toLowerCase().includes(q) ||
          (c.name && c.name.toLowerCase().includes(q))
      );
    }
    res.json({ success: true, count: customers.length, data: customers });
  } catch (error) {
    next(error);
  }
};

export const getCustomerById = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    const customer = dataService.getCustomerById(id);
    if (!customer) {
      return res.status(404).json({ success: false, error: 'Customer not found' });
    }
    const sales = dataService.getCustomerSales(customer.id);
    res.json({ success: true, data: { ...customer, sales } });
  } catch (error) {
    next(error);
  }
};

export const createCustomer = (req: Request, res: Response, next: NextFunction) => {
  try {
    const customer = dataService.createCustomer(req.body);
    res.status(201).json({
      success: true,
      message: 'Customer registered successfully',
      data: customer,
    });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message });
  }
};

export const updateCustomer = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    const customer = dataService.updateCustomer(id, req.body);
    res.json({
      success: true,
      message: 'Customer updated successfully',
      data: customer,
    });
  } catch (error: any) {
    const status = error.message?.includes('not found') ? 404 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
};

export const deleteCustomer = (req: Request, res: Response, next: NextFunction) => {
  try {
    const id = String(req.params.id);
    dataService.deleteCustomer(id);
    res.json({ success: true, message: 'Customer deleted successfully' });
  } catch (error: any) {
    const status = error.message?.includes('not found') ? 404 : 400;
    res.status(status).json({ success: false, error: error.message });
  }
};
