/* SQL supplied by laust_frederiksen@hotmail.com */

drop table addresses;
create table addresses
(
    id           serial primary key,
    name1        char(40),
    name2        char(40),
    name3        char(40),
    name4        char(40)
);

drop table suppliers;
create table suppliers 
(
    id          serial primary key,
    name        char(40),
    address     integer not null,
    foreign key (address) references addresses (id)
);

create unique index suppliers_name on suppliers(name);

drop table manufacturers;
create table manufacturers
(
    id          serial primary key,
    name        char(40),
    address     integer not null,
    foreign key (address) references addresses (id)
);

create unique index manufacturers_name on manufacturers(name);

drop table products;
create table products
(
    id              serial primary key,
    manufacturer    integer not null,
    name            char(40),
    superceded      integer,
    foreign key     (manufacturer) references manufacturers (id),
    foreign key     (superceded)   references products (id)
);

create unique index products_manufacturer_name on products(manufacturer,name);

drop table locations;
create table locations
(
    id          serial primary key,
    name        char(40),
    address     integer not null,
    foreign key (address) references addresses (id)
);

create unique index locations_name on locations(name);

drop table stocks;
create table stocks
(
    id          serial primary key,
    location    integer not null,    
    product     integer not null,
    quantity    integer not null,
    foreign key (location) references locations (id),
    foreign key (product) references products (id)
);

create unique index stocks_location_product on stocks(location,product);

drop table customers;
create table customers
(
    id          integer    auto increment not null,
    name        char(40),
    address     integer not null,
    foreign key (address) references addresses (id)
);

create unique index customers_name on customers(name);

drop table invoices;
create table invoices
(
    id          integer auto increment not null,
    customer    integer not null,
    order_no    char(40),
    address     integer not null,
    order_date  date,
    foreign key (customer) references customers (id),
    foreign key (address) references addresses (id)
);

drop table lines;
create table lines
(
    id          serial primary key,
    invoice     integer not null,
    item        integer not null,
    stock       integer not null,
    quantity    integer,
    foreign key (invoice) references invoices (id),
    foreign key (stock) references stocks (id)
);

create unique index lines_invoice_item on lines(invoice,item);

