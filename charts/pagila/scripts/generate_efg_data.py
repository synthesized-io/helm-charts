import pandas as pd
import random
import string

# Function to generate random strings
def random_string(length=10):
    return ''.join(random.choices(string.ascii_uppercase, k=length))

# Function to generate XML row
def generate_xml_row(row_id, c1, c2, c3, c4, c5):
    xml_template = f"""
    <row id=\"{row_id}\" xml:space=\"preserve\">
        <c1>{c1}</c1>
        <c2>{c2}</c2>
        <c3>{c3}</c3>
        <c4>{c4}</c4>
        <c5>{c5}</c5>
        <c6>CH</c6>
        <c7>CHF</c7>
        <c8>S</c8>
        <c9>101</c9>
        <c10>CHF</c10>
        <c11>0</c11>
        <c15>12.02</c15>
        <c16>20241114</c16>
        <c17>1</c17>
        <c18>84</c18>
        <c47>CH0022268228</c47>
        <c48>CRIMS13871745</c48>
        <c51>0022268220</c51>
        <c53>QUOTED</c53>
        <c54>NO</c54>
        <c55>NO</c55>
        <c56>NO</c56>
        <c57>N</c57>
        <c58>NO</c58>
        <c59>NO</c59>
        <c60>NO</c60>
        <c61>NO</c61>
        <c62>NO</c62>
        <c63>NO</c63>
        <c64>NO</c64>
        <c68>20050926</c68>
        <c73>84</c73>
        <c74>CH</c74>
        <c76>CH</c76>
        <c115>20050926</c115>
        <c125>3753677191</c125>
        <c126>1</c126>
        <c359>9000</c359>
        <c359 m="9">SHA.GUI</c359>
        <c359 m="17">EFGN</c359>
        <c359 m="28">BSI.166027</c359>
        <c359 m="32">CH0010002</c359>
        <c359 m="33">20150131</c359>
        <c359 m="35">EFGN SW Equity</c359>
        <c359 m="49">EQT1</c359>
        <c359 m="50">74</c359>
        <c359 m="51">NA</c359>
        <c359 m="52">N</c359>
        <c359 m="53">30911</c359>
        <c359 m="54">N</c359>
        <c359 m="55">20100216</c359>
        <c359 m="56">EFGIS</c359>
        <c359 m="58">BLOCKED/UNBLOCKED CLASSEUR FMI - BSE 07.02.12</c359>
        <c359 m="69">00</c359>
        <c359 m="87">CHF</c359>
        <c359 m="90">TELEKURS</c359>
        <c359 m="126">Y</c359>
        <c359 m="133">1M</c359>
        <c359 m="144">20241115</c359>
        <c359 m="147">11.86</c359>
        <c359 m="148">20241113</c359>
        <c359 m="202">CH0010001.GLC</c359>
        <c359 m="203">ID-PRC</c359>
        <c359 m="212">CHKLG</c359>
        <c359 m="213">MASTER</c359>
        <c359 m="226">ESVTFR</c359>
        <c359 m="230">4.5757</c359>
        <c359 m="235">8.9</c359>
        <c359 m="259">9</c359>
        <c359 m="260">1</c359>
        <c359 m="264">20240326</c359>
        <c359 m="265">20240328</c359>
        <c359 m="266">IDC</c359>
        <c359 m="272">4.5757</c359>
        <c359 m="280">27.57</c359>
        <c359 m="281">22.78</c359>
        <c359 m="282">78269</c359>
        <c359 m="290">BS1P</c359>
        <c359 m="290" s="2">CH1P</c359>
        <c359 m="290" s="3">CYB</c359>
        <c359 m="290" s="4">GB1P</c359>
        <c359 m="290" s="5">HK1P</c359>
        <c359 m="290" s="6">LI1P</c359>
        <c359 m="290" s="7">LU1P</c359>
        <c359 m="290" s="8">MC1P</c359>
        <c359 m="290" s="9">SG1P</c359>
        <c359 m="290" s="10">US1P</c359>
        <c359 m="310">OUT</c359>
        <c359 m="311">20140701</c359>
        <c359 m="324">EQUITIES-EQ_CH</c359>
        <c359 m="325">222682-200</c359>
        <c359 m="326">0.25</c359>
        <c359 m="332">222682-200</c359>
        <c359 m="333">171922</c359>
        <c359 m="346">EFGN</c359>
        <c359 m="350">NO</c359>
        <c359 m="370">YES</c359>
        <c359 m="386">66.12</c359>
        <c362>2</c362>
        <c363>MAPPED_OFS-EXPL</c363>
        <c363 m="2">43_CONV.SECURITY.MASTER.G15.2.00</c363>
        <c363 m="3">45_CONV.SECURITY.MASTER.R07</c363>
        <c363 m="4">45_CONV.SECURITY.MASTER.R08</c363>
        <c363 m="5">45_CONV.SECURITY.MASTER.R09</c363>
        <c363 m="6">45_CONV.SECURITY.MASTER.201804</c363>
        <c364>2411150824</c364>
        <c365>MAPPED_SHDN.SM.NACE</c365>
        <c366>CH0010001</c366>
        <c367>8100</c367>
        <c369/>
    </row>"""
    return xml_template

# Generate 10,000 rows
data = []
for i in range(100000):
    row_id = f"222682-{200 + i}"
    c1 = f"Company_{i} {random_string(5)}"
    c2 = f"Alias_{i} {random_string(4)}"
    c3 = f"Description_{i}"
    c4 = f"SYM_{random_string(3)}"
    c5 = f"Country_{random.choice(['US', 'CH', 'DE', 'FR', 'UK'])}"
    xml_row = generate_xml_row(row_id, c1, c2, c3, c4, c5)
    data.append((row_id, xml_row))

# Convert to DataFrame
df = pd.DataFrame(data, columns=['key', 'value'])

# Generate SQL INSERT statements
with open("insert_security_master.sql", "w") as f:
    for index, row in df.iterrows():
        f.write(f"INSERT INTO trading_schema.SECURITY_MASTER (key, value) VALUES (\'{row['key']}\', '{row['value']}');\n")

print("SQL File Generated: insert_security_master.sql")
